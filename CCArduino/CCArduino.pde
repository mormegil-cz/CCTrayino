#include "vspde.h"

#define MAXPROJECTS 3

#define PIN_LED_BASE 2
#define PIN_BUZZER 12

#define PIN_LED_RED(i) (PIN_LED_BASE + 2 * (i))
#define PIN_LED_GREEN(i) (PIN_LED_BASE + 2 * (i) + 1)

// protocol
#define COMMAND_BASE 65
#define COMMAND_TYPES 5

#define STATE_NOTCONNECTED 0
#define STATE_OK 1
#define STATE_BUILDING 2
#define STATE_BROKEN 3
#define STATE_BROKENBUILDING 4

#define BUZZERSTATE_SILENT 0
#define BUZZERSTATE_BUILT 1
#define BUZZERSTATE_BUILDING 2
#define BUZZERSTATE_FIXED 3
#define BUZZERSTATE_BROKE 4

// variables
byte state[MAXPROJECTS];
byte buzzerstate;
boolean blinker;
unsigned long buzzerstart;
unsigned long lastblink;

void setup() {
	for (int i = 0; i < MAXPROJECTS; ++i) {
		state[i] = STATE_NOTCONNECTED;
		pinMode(PIN_LED_RED(i), OUTPUT);
		pinMode(PIN_LED_GREEN(i), OUTPUT);
	}
	buzzerstate = BUZZERSTATE_SILENT;
	Serial.begin(9600);

	lastblink = millis();
}

void buzzer(byte state) {
	if (buzzerstate >= state) return;

	buzzerstate = state;
	noTone(PIN_BUZZER);
	switch(state) {
		case BUZZERSTATE_BUILT:
			tone(PIN_BUZZER, 4000, 150);
			break;
		case BUZZERSTATE_BUILDING:
			tone(PIN_BUZZER, 5000, 150);
			break;
		case BUZZERSTATE_FIXED:
			tone(PIN_BUZZER, 12000, 500);
			break;
		case BUZZERSTATE_BROKE:
			tone(PIN_BUZZER, 800, 1500);
			break;
	}
	buzzerstate = BUZZERSTATE_SILENT;
}

void process_input() {
	byte in = Serial.read();

	if (in < COMMAND_BASE) return;
	in -= COMMAND_BASE;

	byte project = in / COMMAND_TYPES;
	byte command = in % COMMAND_TYPES;

	if (project > MAXPROJECTS) return;

	byte currstate = state[project];
	if (command == currstate) return;

	state[project] = command;
	boolean checkbuzzer = false;
	switch(command) {
		case STATE_NOTCONNECTED:
		case STATE_OK:
			switch(currstate) {
				case STATE_NOTCONNECTED:
				case STATE_OK:
					break;
		                case STATE_BUILDING:
					buzzer(BUZZERSTATE_BUILT);
					break;
				case STATE_BROKEN:
				case STATE_BROKENBUILDING:
					buzzer(BUZZERSTATE_FIXED);
					break;
			}
			break;
			checkbuzzer = currstate > STATE_OK;
			break;
		case STATE_BUILDING:
			switch(currstate) {
				case STATE_NOTCONNECTED:
				case STATE_OK:
					buzzer(BUZZERSTATE_BUILDING);
					break;
				case STATE_BROKEN:
				case STATE_BROKENBUILDING:
					buzzer(BUZZERSTATE_FIXED);
					break;
			}
			break;
		case STATE_BROKEN:
			if (currstate < STATE_BROKEN) buzzer(BUZZERSTATE_BROKE);
			break;
		case STATE_BROKENBUILDING:
			switch(currstate) {
				case STATE_NOTCONNECTED:
				case STATE_OK:
				case STATE_BUILDING:
					buzzer(BUZZERSTATE_BROKE);
					break;
				case STATE_BROKEN:
					buzzer(BUZZERSTATE_BUILDING);
					break;
			}
			break;
	}

        Serial.println("Project states: ");
	for (int i = 0; i < MAXPROJECTS; ++i) {
          Serial.print(i, DEC);
          Serial.print(": ");
	  Serial.println(state[i], DEC);
        }

	if (checkbuzzer) {
		boolean silence = true;
		for (int i = 0; i < MAXPROJECTS; ++i) {
			if (state[project] > STATE_OK) {
				silence = false;
				break;
			}
		}
		if (silence) {
			buzzerstate = BUZZERSTATE_SILENT;
			noTone(PIN_BUZZER);
		}
	}
}

void update_state(int project, byte state) {
	boolean red, green;
	switch(state) {
		case STATE_NOTCONNECTED:
			red = false;
			green = false;
			break;
		case STATE_OK:
			red = false;
			green = true;
			break;
		case STATE_BUILDING:
			red = false;
			green = blinker;
			break;
		case STATE_BROKEN:
			red = true;
			green = false;
			break;
		case STATE_BROKENBUILDING:
			red = blinker;
			green = false;
			break;
	}

	digitalWrite(PIN_LED_RED(project), red ? LOW : HIGH);
	digitalWrite(PIN_LED_GREEN(project), green ? LOW : HIGH);
}

void loop() {
	while (Serial.available() > 0) process_input();
	for (int i = 0; i < MAXPROJECTS; ++i) update_state(i, state[i]);

	// update blinker
	unsigned long t = millis();
	if (t - lastblink > 500) {
		blinker = !blinker;
		lastblink = t;
	}
}
