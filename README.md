# 📱 Flutter Mobile Robot Remote Controller

A Flutter-based application that allows users to remotely control a
mobile robot using Bluetooth communication.\
This app provides an intuitive interface for sending commands,
monitoring robot status, and managing connectivity---all directly from
an Android device.

## 🚀 Features

-   **Bluetooth Connectivity**
-   **Real-Time Movement Control**
-   **Connection Status Monitoring**
-   **Command Console for Debugging**

## 🛠️ Tech Stack

-   Flutter (Dart)
-   flutter_bluetooth_serial
-   Android support

## 📡 Robot Requirements

-   Bluetooth module (HC-05 / HC-06)
-   Receives serial commands:
    -   F → Forward
    -   B → Backward
    -   L → Left
    -   R → Right
    -   S → Stop

## 🔧 Installation

``` bash
git clone https://github.com/owlyas/evobot-remote-v2.git
flutter pub get
flutter run
```

## 📱 Usage

1.  Power on robot Bluetooth.
2.  Scan for devices using the app.
3.  Select HC-05 / HC-06.
4.  Use the on-screen controls to move the robot.

## 📦 Project Structure

    lib/
     ├─ main.dart
     ├─ pages/
     ├─ controllers/
     └─ widgets/

## 🧪 Future Improvements

-   Joystick UI
-   WiFi control support
-   Sensor telemetry
-   Camera streaming

## 🤝 Contributions

Pull requests are welcome!

## 📄 License

MIT License
