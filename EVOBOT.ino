//||======================||
//||--------EVOBOT--------||
//||======================||

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

//===== UUID BLE UART =====
#define SERVICE_UUID           "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHARACTERISTIC_RX_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define CHARACTERISTIC_TX_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"


//===== Motor Driver 1 (Depan) =====
#define ENA1 25
#define IN1  26
#define IN2  27

#define ENB1 13
#define IN3  14
#define IN4  12

//===== Motor Driver 2 (Belakang) =====
#define ENA2 32
#define IN5  33
#define IN6  4

#define ENB2 15
#define IN7  5
#define IN8  18

//===== Microphone =====



//===== Speaker =====



//===== Buzzer =====
#define BUZZER 23


//===== Ultrasonic =====
#define TRIG 19
#define ECHO 21

int PWM_SPEED = 100;   // Kecepatan default (0–255)
bool speechControlMode = false;   //Setting mode awal
bool obstacleDetectitonMode = false;   //Setting sensor ultrasonic
BLECharacteristic *txCharacteristic;
String data;

//===== Callback BLE RX (Joystick Controller) =====
class RxCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) {
    String rxValue = characteristic->getValue();

    if (rxValue.length() > 0) {
      Serial.print("Perintah diterima: ");
      Serial.println(rxValue.c_str());

      // ===== Perintah Gerakan =====
      if (rxValue == "F") forward();
      else if (rxValue == "B") backward();
      else if (rxValue == "L") turnLeft();
      else if (rxValue == "R") turnRight();
      else if (rxValue == "S") stopRobot();

      // ===== Pengaturan Kecepatan dari Flutter (Format: V50) =====
      String received = String(rxValue.c_str());

      if (received.startsWith("V")) {
        String speedStr = received.substring(1);   // ambil angka setelah huruf V
        int newSpeed = speedStr.toInt();

        if (newSpeed < 0) newSpeed = 0;
        if (newSpeed > 255) newSpeed = 255;

        PWM_SPEED = newSpeed;

        Serial.print("Kecepatan diubah ke: ");
        Serial.println(PWM_SPEED);
      }
    }
  }
};


//===== Setup =====
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("READY");

  //===== Setup BLE =====
  BLEDevice::init("EVOBOT");            // Nama perangkat BLE
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // RX (menerima data dari Flutter)
  BLECharacteristic *rxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  rxCharacteristic->setCallbacks(new RxCallback());

  // TX (mengirim data ke Flutter)
  txCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_TX_UUID,
  BLECharacteristic::PROPERTY_NOTIFY
  );
  txCharacteristic->addDescriptor(new BLE2902());

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();

  Serial.println(BLEDevice::getAddress().toString().c_str());


  Serial.println("BLE UART siap digunakan!");

  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);

  pinMode(IN5, OUTPUT); pinMode(IN6, OUTPUT);
  pinMode(IN7, OUTPUT); pinMode(IN8, OUTPUT);

  pinMode(ENA1, OUTPUT);
  pinMode(ENB1, OUTPUT);
  pinMode(ENA2, OUTPUT);
  pinMode(ENB2, OUTPUT);

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
  digitalWrite(IN5, LOW);
  digitalWrite(IN6, LOW);
  digitalWrite(IN7, LOW);
  digitalWrite(IN8, LOW);

  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);

  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);

  tone(BUZZER, 6000);
  delay(1000);
  noTone(BUZZER);

}

void loop() {
  //===== Mode switch =====

  
}

//===== Auto Mode =====
void autonomousMode() {
  
}

//===== Motor Function =====
void forward() {
  motorLeftForward();
  motorRightForward();
}

void backward() {
  motorLeftBackward();
  motorRightBackward();
}

void turnLeft() {
  motorTurnLeft();
}

void turnRight() {
  motorTurnRight();
}

void stopRobot() {
  motorLeftStop();
  motorRightStop();
}

// LEFT SIDE = ENA1 + ENB1
void motorLeftForward() {
  analogWrite(ENA1, PWM_SPEED);
  analogWrite(ENB1, PWM_SPEED);

  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);

  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void motorLeftBackward() {
  analogWrite(ENA1, PWM_SPEED);
  analogWrite(ENB1, PWM_SPEED);

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);

  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
}

void motorLeftStop() {
  analogWrite(ENA1, 0);
  analogWrite(ENB1, 0);

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}

// RIGHT SIDE = ENA2 + ENB2
void motorRightForward() {
  analogWrite(ENA2, PWM_SPEED);
  analogWrite(ENB2, PWM_SPEED);

  digitalWrite(IN5, HIGH);
  digitalWrite(IN6, LOW);

  digitalWrite(IN7, HIGH);
  digitalWrite(IN8, LOW);
}

void motorRightBackward() {
  analogWrite(ENA2, PWM_SPEED);
  analogWrite(ENB2, PWM_SPEED);

  digitalWrite(IN5, LOW);
  digitalWrite(IN6, HIGH);

  digitalWrite(IN7, LOW);
  digitalWrite(IN8, HIGH);
}

void motorRightStop() {
  analogWrite(ENA2, 0);
  analogWrite(ENB2, 0);

  digitalWrite(IN5, LOW);
  digitalWrite(IN6, LOW);
  digitalWrite(IN7, LOW);
  digitalWrite(IN8, LOW);
}

void motorSlow() {
  analogWrite(ENA2, PWM_SPEED * 0.4);
  analogWrite(ENB2, PWM_SPEED * 0.4);

  digitalWrite(IN5, HIGH);
  digitalWrite(IN6, LOW);

  digitalWrite(IN7, HIGH);
  digitalWrite(IN8, LOW);

  analogWrite(ENA1, PWM_SPEED * 0.4);
  analogWrite(ENB1, PWM_SPEED * 0.4);

  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);

  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void motorTurnLeft() {
  analogWrite(ENA1, PWM_SPEED); analogWrite(ENB1, PWM_SPEED);
  analogWrite(ENA2, PWM_SPEED); analogWrite(ENB2, PWM_SPEED);

  digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH);

  digitalWrite(IN5, HIGH); digitalWrite(IN6, LOW);
  digitalWrite(IN7, LOW); digitalWrite(IN8, HIGH);
}

void motorTurnRight() {
  analogWrite(ENA1, PWM_SPEED); analogWrite(ENB1, PWM_SPEED);
  analogWrite(ENA2, PWM_SPEED); analogWrite(ENB2, PWM_SPEED);

  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);

  digitalWrite(IN5, LOW); digitalWrite(IN6, HIGH);
  digitalWrite(IN7, HIGH); digitalWrite(IN8, LOW);
}

//===== Color detection =====
void ColorDetection() {
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();

    int commaIndex = input.indexOf(',');
    if (commaIndex > 0) {

      String color = input.substring(0, commaIndex);
      String direction = input.substring(commaIndex + 1);

      // Debug
      if (color == "GREEN"){
        if (direction == "FORWARD"){
          forward();
        }
        else if (direction == "LEFT"){
          turnLeft();
        }
        else if (direction == "RIGHT"){
          turnRight();
        }
        else if (direction == "SLOW"){
          motorSlow();
        }
        else if (direction == "STOP"){
          stopRobot();
        }
        else 
          stopRobot();
      }

      Serial.println("COLOR: " + color);
      Serial.println("DIR: " + direction);                           
    }
  }
}


//===== Ultrasonic =====
long readDistance() {
  digitalWrite(TRIG, LOW);
  delayMicroseconds(5);
  digitalWrite(TRIG, HIGH);
  delayMicroseconds(15);
  digitalWrite(TRIG, LOW);

  long duration = pulseIn(ECHO, HIGH, 60000);
  if (duration == 0) return 500;  // no echo → anggap jauh

  long dist = duration * 0.034 / 2;
  return dist;
}