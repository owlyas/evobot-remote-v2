// ===== MOTOR DRIVER 1 (DEPAN) =====
#define ENA1 25
#define IN1  26
#define IN2  27

#define ENB1 13
#define IN3  14
#define IN4  12

// ===== MOTOR DRIVER 2 (BELAKANG) =====
#define ENA2 32
#define IN5  33
#define IN6  4

#define ENB2 15
#define IN7  5
#define IN8  18

// ===== BUZZER =====
#define BUZZER 23

// ===== ULTRASONIC =====
#define TRIG 19
#define ECHO 21

int PWM_SPEED = 100;   // Kecepatan default (0–255)
bool autonomousMode = false;
bool sensorEnabled = true;  // Sensor aktif secara default

// ==========================
// SETUP
// ==========================
void setup() {
  Serial.begin(115200);
  
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(IN5, OUTPUT); pinMode(IN6, OUTPUT);
  pinMode(IN7, OUTPUT); pinMode(IN8, OUTPUT);
  pinMode(ENA1, OUTPUT);
  pinMode(ENB1, OUTPUT);
  pinMode(ENA2, OUTPUT);
  pinMode(ENB2, OUTPUT);

  stopRobot();

  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);

  tone(BUZZER, 6000);
  delay(1000);
  noTone(BUZZER);

  Serial.println("🚗 ESP32 4WD + Flutter READY");
  Serial.println("Sensor Ultrasonik: AKTIF");
}

// ==========================
// LOOP
// ==========================
void loop() {
  // ===== TERIMA COMMAND DARI FLUTTER VIA BLUETOOTH =====
  if (Serial.available() > 0) {
    char command = Serial.read();
    
    Serial.print("Received: ");
    Serial.println(command);
    
    switch(command) {
      case 'F':  // Forward (Maju)
        if (sensorEnabled) {
          // Cek jarak dulu sebelum maju
          long dist = readDistance();
          if (dist > 30) {
            forward();
          } else {
            stopRobot();
            tone(BUZZER, 3000, 200);  // Beep peringatan
            Serial.println("⚠️ Obstacle detected!");
          }
        } else {
          forward();  // Maju tanpa cek sensor
        }
        break;
        
      case 'B':  // Backward (Mundur)
        backward();
        break;
        
      case 'L':  // Turn Left (Belok Kiri)
        turnLeft();
        break;
        
      case 'R':  // Turn Right (Belok Kanan)
        turnRight();
        break;
        
      case 'S':  // Stop (Berhenti)
        stopRobot();
        noTone(BUZZER);
        break;
        
      case 'A':  // Button A (Klakson)
        tone(BUZZER, 6000);
        break;
        
      case 'B':  // Button B (Stop klakson)
        noTone(BUZZER);
        break;
        
      case 'X':  // Button X (Mode Autonomous)
        autonomousMode = true;
        sensorEnabled = true;  // Sensor wajib aktif di mode autonomous
        Serial.println("Mode: AUTONOMOUS");
        Serial.println("Sensor: AKTIF");
        break;
        
      case 'Y':  // Button Y (Toggle Sensor)
        if (!autonomousMode) {  // Hanya bisa toggle jika tidak di mode autonomous
          sensorEnabled = !sensorEnabled;
          
          // Beep feedback
          if (sensorEnabled) {
            tone(BUZZER, 4000, 100);
            delay(150);
            tone(BUZZER, 5000, 100);
            Serial.println("✅ Sensor Ultrasonik: AKTIF");
          } else {
            tone(BUZZER, 3000, 100);
            delay(150);
            tone(BUZZER, 2000, 100);
            Serial.println("❌ Sensor Ultrasonik: NONAKTIF");
          }
        } else {
          Serial.println("⚠️ Tidak bisa nonaktifkan sensor saat mode AUTONOMOUS");
          tone(BUZZER, 2000, 200);
        }
        break;
        
      case 'V':  // Speed Value
        int speed = Serial.parseInt();
        PWM_SPEED = constrain(speed, 0, 255);
        Serial.print("Speed updated: ");
        Serial.println(PWM_SPEED);
        break;
    }
  }
  
  // Mode Autonomous (sensor selalu aktif)
  if (autonomousMode) {
    autonomousControl();
  }
}

// =======================================================
// ================== AUTONOMOUS MODE ====================
// =======================================================
void autonomousControl() {
  long d = readDistance();

  Serial.print("AUTO DIST = ");
  Serial.println(d);

  if (d > 30) {
    forward();
  }
  else if (d <= 30) {
    stopRobot();
    delay(1000);
    turnRight();
    delay(700);
  }
}

// ==========================
// MOTOR FUNCTIONS
// ==========================
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

// =======================================================
// ================== ULTRASONIC =========================
// =======================================================
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