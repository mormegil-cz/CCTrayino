using System;
using System.Configuration;
using System.IO.Ports;
using System.Threading;

namespace CCTrayino
{
    class Program
    {
        static void Main(string[] args)
        {
            int i;
            string port = "COM3";
            int rate = 9600;

            for (i = 0; i < args.Length; ++i)
            {
                var arg = args[i];
                if (!arg.StartsWith("-")) break;
                arg = arg.Substring(1);
                switch (arg)
                {
                    case "p":
                        port = args[++i];
                        break;
                    case "r":
                        rate = Int32.Parse(args[++i]);
                        break;
                    default:
                        Console.Error.WriteLine("Unknown argument");
                        Environment.Exit(2);
                        return;
                }
            }
            if (i != args.Length - 2)
            {
                Console.Error.WriteLine("Usage: CCTraino [options] project state");
                Console.Error.WriteLine("Where:");
                Console.Error.WriteLine("\tproject is the name of the project");
                Console.Error.WriteLine("\tstate is one of NOTCONNECTED OK BUILDING BROKEN BROKENBUILDING");
                Console.Error.WriteLine("Options:");
                Console.Error.WriteLine("\t-p PORT\t(Default is COM3)");
                Console.Error.WriteLine("\t-r RATE\t(Default is 9600)");
                Environment.Exit(2);
                return;
            }

            var project = args[i];
            var state = args[i + 1];

            int stateNum;
            switch (state.ToLowerInvariant())
            {
                case "notconnected":
                    stateNum = 0;
                    break;
                case "ok":
                    stateNum = 1;
                    break;
                case "building":
                    stateNum = 2;
                    break;
                case "broken":
                    stateNum = 3;
                    break;
                case "brokenbuilding":
                    stateNum = 4;
                    break;
                default:
                    Console.Error.WriteLine("Invalid state");
                    Environment.Exit(2);
                    return;
            }

            var projectNum = 0;
            while (true)
            {
                ++projectNum;
                var projName = ConfigurationManager.AppSettings["project." + projectNum];
                if (projName == null)
                {
                    Console.Error.WriteLine("Unknown project");
                    Environment.Exit(2);
                    return;
                }
                if (projName == project) break;
            }

            using (var com = new SerialPort(port, rate))
            {
                // wait until COM available
                int retries = 0;
                while (true)
                {
                    try
                    {
                        com.Open();
                        break;
                    }
                    catch (UnauthorizedAccessException)
                    {
                        Thread.Sleep(100);
                        if (++retries > 100)
                        {
                            Console.Error.WriteLine("Failed to open port {0}", port);
                            Environment.Exit(1);
                        }
                    }
                }

                var data = new byte[1];
                data[0] = (byte)((projectNum - 1) * 5 + stateNum + 'A');
                /*
                using (var log = new StreamWriter(Path.Combine(Path.GetDirectoryName(Assembly.GetEntryAssembly().Location), "cctrayino.log"), true))
                    log.WriteLine("{3}: Project {0}, state {1} (code {2})", projectNum, stateNum, data[0], DateTime.Now);
                */
                com.Write(data, 0, 1);
            }
        }
    }
}
