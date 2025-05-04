#include <esp32-hal-ledc.h>
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

uint8_t slaveMAC[] = {0x60, 0x8A, 0x10, 0x64, 0xA0, 0xA9};

// Motor Pins
#define AIN1 12
#define AIN2 21
#define PWMA 25
#define BIN1 4
#define BIN2 2
#define PWMB 26

// Encoders
#define ENCODER_A 33
#define ENCODER_B 32

// Ultrasonic
#define TRIG_PIN 5
#define ECHO_PIN 19
#define WALL_DISTANCE_CM 7

// Motor Config
#define PWM_FREQ 1000
#define PWM_CHANNEL_A 0
#define PWM_CHANNEL_B 1
#define PWM_RESOLUTION 8

#define WHEEL_DIAMETER 4.6
#define WHEEL_CIRCUMFERENCE (3.1416 * WHEEL_DIAMETER)
#define WHEEL_BASE_CM 12.0
#define PPR 7
#define DISTANCE_CM_TO_TRAVEL 15

// Encoder Tracking
volatile long encoderCount = 0;
int lastEncoded = 0;

// Bluetooth + Control
bool connected = false;
unsigned long lastAttemptTime = 0;
const unsigned long reconnectInterval = 5000;

// Buffer
#define MAX_COMMANDS 10
uint8_t commandBuffer[MAX_COMMANDS];
int commandIndex = 0;
int totalCommands = 0;
uint8_t wallStatusBits = 0;
bool skipInitialWallCheck = false;

// Absolute orientation tracking
enum Direction { NORTH, EAST, SOUTH, WEST };
Direction currentOrientation = NORTH;

void IRAM_ATTR encoderISR() {
  int MSB = digitalRead(ENCODER_A);
  int LSB = digitalRead(ENCODER_B);
  int encoded = (MSB << 1) | LSB;
  int sum = (lastEncoded << 2) | encoded;

  if (sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) encoderCount++;
  if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) encoderCount--;

  lastEncoded = encoded;
}

void setup() {
  Serial.begin(115200);
  SerialBT.begin("ESP32_MASTER", true);
  Serial.println("ESP32 Master started. Attempting connection...");
  connectToSlave();

  pinMode(AIN1, OUTPUT); pinMode(AIN2, OUTPUT);
  pinMode(BIN1, OUTPUT); pinMode(BIN2, OUTPUT);
  ledcAttachChannel(PWMA, PWM_FREQ, PWM_RESOLUTION, PWM_CHANNEL_A);
  ledcAttachChannel(PWMB, PWM_FREQ, PWM_RESOLUTION, PWM_CHANNEL_B);

  pinMode(ENCODER_A, INPUT_PULLUP);
  pinMode(ENCODER_B, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ENCODER_A), encoderISR, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_B), encoderISR, CHANGE);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  if (!SerialBT.connected()) {
    if (connected) {
      Serial.println("Disconnected. Attempting reconnect...");
      connected = false;
    }

    if (millis() - lastAttemptTime > reconnectInterval) {
      connectToSlave();
      lastAttemptTime = millis();
    }
    return;
  }

  if (!connected) {
    Serial.println("Reconnected to Slave!");
    connected = true;
  }

  while (true) {
    receiveCommands();
    skipInitialWallCheck = true;
    executeCommands();
  }
}

void receiveCommands() {
  totalCommands = 0;
  wallStatusBits = 0;

  Serial.println("Waiting for new commands...");
  while (!SerialBT.available()) delay(100);

  while (SerialBT.available()) {
    uint8_t incoming = SerialBT.read();
    if (incoming == 0xFF) {
      stopMotors();
      Serial.println("STOP command received.");
      return;
    }
    if (totalCommands < MAX_COMMANDS) {
      commandBuffer[totalCommands++] = incoming & 0x0F;
      Serial.print("Buffered command: ");
      Serial.println(incoming & 0x0F, HEX);
    }
  }
}

void executeCommands() {
  for (commandIndex = 0; commandIndex < totalCommands; commandIndex++) {
    uint8_t cmd = commandBuffer[commandIndex];
    Serial.print("Executing: 0x"); Serial.println(cmd, HEX);

    // Wall check before move
    if (!skipInitialWallCheck) {
      long dist = readDistanceCM();
      if (dist > 0 && dist < WALL_DISTANCE_CM) {
        Serial.println("Wall detected before movement.");
        wallStatusBits |= (1 << (totalCommands - 1 - commandIndex));
        sendWallStatus();
        stopMotors();
        return;
      }
    }
    skipInitialWallCheck = false;

    // Convert command to absolute direction
    Direction targetOrientation;
    switch (cmd) {
      case 0x08: targetOrientation = NORTH; break;
      case 0x01: targetOrientation = SOUTH; break;
      case 0x04: targetOrientation = EAST; break;
      case 0x02: targetOrientation = WEST; break;
      default: continue;
    }

    int rotation = (targetOrientation - currentOrientation + 4) % 4;
    if (rotation == 1) {
      turnRightAngle(90);
      currentOrientation = (Direction)((currentOrientation + 1) % 4);
    } else if (rotation == 2) {
      turnRightAngle(180);
      currentOrientation = (Direction)((currentOrientation + 2) % 4);
    } else if (rotation == 3) {
      turnLeftAngle(90);
      currentOrientation = (Direction)((currentOrientation + 3) % 4);
    }

    // Move forward in new direction
    moveForDistance(DISTANCE_CM_TO_TRAVEL);

    // Wall check after move
    long dist = readDistanceCM();
    if (dist > 0 && dist < WALL_DISTANCE_CM) {
      Serial.println("Wall detected after movement.");
      wallStatusBits |= (1 << (totalCommands - 1 - commandIndex));
      sendWallStatus();
      stopMotors();
      return;
    }

    delay(300); // pause between moves
  }

  Serial.println("All commands executed.");
}

void sendWallStatus() {
  uint8_t position = commandIndex + 1;
  uint8_t report = (position << 4) | 0x01;
  Serial.print("Sending wall report: ");
  Serial.println(report, BIN);
  SerialBT.write(report);

  Serial.println("Waiting for next direction...");
  totalCommands = 0;
  wallStatusBits = 0;

  while (!SerialBT.available()) delay(100);
}

// === Movement Functions ===
void moveMotor(int in1, int in2, int pwmChannel, int speed) {
  if (speed > 0) { digitalWrite(in1, HIGH); digitalWrite(in2, LOW); }
  else if (speed < 0) { digitalWrite(in1, LOW); digitalWrite(in2, HIGH); speed = -speed; }
  else { digitalWrite(in1, LOW); digitalWrite(in2, LOW); }
  ledcWriteChannel(pwmChannel, speed);
}

void stopMotors() {
  moveMotor(AIN1, AIN2, PWM_CHANNEL_A, 0);
  moveMotor(BIN1, BIN2, PWM_CHANNEL_B, 0);
}

void moveForDistance(float distance_cm) {
  encoderCount = 0;
  float ticks = 70 * (distance_cm / WHEEL_CIRCUMFERENCE) * PPR;
  moveMotor(AIN1, AIN2, PWM_CHANNEL_A, 180);
  moveMotor(BIN1, BIN2, PWM_CHANNEL_B, 180);
  while (abs(encoderCount) < ticks) delay(5);
  stopMotors();
}

void moveBackwardForDistance(float distance_cm) {
  encoderCount = 0;
  float ticks = 70 * (distance_cm / WHEEL_CIRCUMFERENCE) * PPR;
  moveMotor(AIN1, AIN2, PWM_CHANNEL_A, -180);
  moveMotor(BIN1, BIN2, PWM_CHANNEL_B, -180);
  while (abs(encoderCount) < ticks) delay(5);
  stopMotors();
}

void turnLeftAngle(float angle_deg) {
  encoderCount = 0;
  float arc = (3.1416 * WHEEL_BASE_CM * angle_deg) / 360.0;
  float ticks = 130 * (arc / WHEEL_CIRCUMFERENCE) * PPR;
  moveMotor(AIN1, AIN2, PWM_CHANNEL_A, -130);
  moveMotor(BIN1, BIN2, PWM_CHANNEL_B, 130);
  while (abs(encoderCount) < ticks) delay(5);
  stopMotors();
}

void turnRightAngle(float angle_deg) {
  encoderCount = 0;
  float arc = (3.1416 * WHEEL_BASE_CM * angle_deg) / 360.0;
  float ticks = 130 * (arc / WHEEL_CIRCUMFERENCE) * PPR;
  moveMotor(AIN1, AIN2, PWM_CHANNEL_A, 130);
  moveMotor(BIN1, BIN2, PWM_CHANNEL_B, -130);
  while (abs(encoderCount) < ticks) delay(5);
  stopMotors();
}

// === Ultrasonic Distance ===
long readDistanceCM() {
  digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  return duration * 0.034 / 2;
}

// === Bluetooth Connection ===
void connectToSlave() {
  Serial.println("Searching for slave...");
  if (SerialBT.connect(slaveMAC)) {
    Serial.println("Connected to ESP32 Slave!");
    connected = true;
  } else {
    Serial.println("Failed to connect. Retrying...");
    connected = false;
  }
}