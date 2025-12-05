import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';

// UUIDs for UART communication
const String targetServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const String txCharUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";

class ControllerPage extends StatefulWidget {
  const ControllerPage({Key? key}) : super(key: key);

  @override
  ControllerPageState createState() => ControllerPageState();
}

class ControllerPageState extends State<ControllerPage> {
  bool isConnected = false;
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? txCharacteristic;
  bool isWifiScanning = false;
  List<WifiNetwork> wifiNetworks = [];
  Timer? stopTimer;
  List<ScanResult> scanResults = [];
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  Map<String, bool> buttonStates = {
    'UP': false,
    'DOWN': false,
    'LEFT': false,
    'RIGHT': false,
    'X': false,
    'Y': false,
    'A': false,
    'B': false,
  };

  double speedValue = 50.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    FlutterBluePlus.adapterState.listen((state) {
      print('Bluetooth Adapter State: $state');
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    stopScan();
    super.dispose();
  }
  
  Future<void> startWifiScan() async {
    setState(() => isWifiScanning = true);

    try {
      final List<WifiNetwork>? results =
          await WiFiForIoTPlugin.loadWifiList();

      setState(() {
        wifiNetworks = results ?? [];
        isWifiScanning = false;
      });
    } catch (e) {
      setState(() => isWifiScanning = false);
    }
  }

  void stopWifiScan() {
    setState(() => isWifiScanning = false);
  }

  void showWifiPasswordDialog(String ssid) {
    TextEditingController pass = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Connect to $ssid"),
          content: TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Connect"),
              onPressed: () async {
                Navigator.pop(context);

                bool success = await WiFiForIoTPlugin.connect(
                  ssid,
                  password: pass.text,
                  security: NetworkSecurity.WPA,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? "Connected to $ssid"
                          : "Failed to connect to $ssid",
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void showWifiDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.grey[50],
              title: Row(
                children: [
                  const Icon(Icons.wifi, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  const Text(
                    'WiFi Networks',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    if (isWifiScanning)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.blueAccent,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Scanning for WiFi networks...",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),


                  Expanded(
                    child: wifiNetworks.isEmpty
                        ? Center(
                            child: Text(
                              isWifiScanning
                                  ? "Searching nearby WiFi..."
                                  : "No WiFi networks found.",
                              style: const TextStyle(
                                color: Color.fromARGB(255, 10, 10, 10),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: wifiNetworks.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: Colors.grey[300]),
                            itemBuilder: (context, index) {
                              final wifi = wifiNetworks[index];
                              final ssid = wifi.ssid ?? "Unknown";

                               return ListTile(
                                leading: const Icon(Icons.wifi,
                                    color: Colors.blueAccent),
                                title: Text(
                                  ssid,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 75, 75, 75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  "Signal: ${wifi.level} dBm",
                                  style:
                                      TextStyle(color: Colors.grey[700]),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  showWifiPasswordDialog(ssid);
                                },
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),

              actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWifiScanning
                        ? Colors.redAccent
                        : Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isWifiScanning ? Icons.stop : Icons.search,
                    color: Colors.white,
                  ),
                  label: Text(
                    isWifiScanning ? 'Stop Scan' : 'Start Scan',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    if (isWifiScanning) {
                      stopWifiScan();
                    } else {
                      startWifiScan();

                      // auto stop after 10 sec (same as Bluetooth)
                      Future.delayed(const Duration(seconds: 10), () {
                        if (isWifiScanning) {
                          stopWifiScan();
                          setDialogState(() {}); // refresh dialog
                        }
                      });
                    }
                    setDialogState(() {});
                  },
                ),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> startScan() async {
    try {
      setState(() {
        isScanning = true;
        scanResults.clear();
      });

      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          scanResults = results;
        });
      });

      await Future.delayed(Duration(seconds: 15));
      await stopScan();
    } catch (e) {
      print('Error starting scan: $e');
      showError('Failed to start scan: $e');
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      setState(() {
        isScanning = false;
      });
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      connectedDevice = device;
      isConnected = true;
      setState(() {});

      print('✅ Connected! Discovering services...');
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == targetServiceUUID) {
          print('✅ UART Service found');

          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString().toLowerCase() == txCharUUID) {
              txCharacteristic = c;
              print('✅ TX Characteristic ready: ${c.uuid}');
              showSuccess('Ready to control ESP32 🚗');
            }
          }
        }
      }

      if (txCharacteristic == null) {
        print('❌ TX characteristic NOT FOUND');
        showError('Cannot control ESP32 – TX characteristic missing!');
      }
    } catch (e) {
      print('❌ Error connecting: $e');
      showError('Connection failed');
    }
  }

  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        setState(() {
          isConnected = false;
          connectedDevice = null;
          txCharacteristic = null;
        });
        showSuccess('Bluetooth Disconnected');
      } catch (e) {
        print('Error disconnecting: $e');
      }
    }
  }

  Future<void> sendData(String command) async {
    if (txCharacteristic == null || !isConnected) {
      print('❌ Cannot send – Not connected or no TX characteristic');
      return;
    }

    List<int> bytes = command.codeUnits;
    await txCharacteristic!.write(bytes, withoutResponse: false);

    print('📤 Sent command: $command → bytes: $bytes');
  }

  void onButtonPressed(String button) {
    setState(() {
      buttonStates[button] = true;
    });

    String command = switch (button) {
      'UP' => 'F',
      'DOWN' => 'B',
      'LEFT' => 'L',
      'RIGHT' => 'R',
      _ => 'S',
    };

    if (command != 'S') {
      sendData(command);
    } else if (button == 'A') {
      sendData('A');
    } else if (button == 'B') {
      sendData('B');
    } else if (button == 'X') {
      sendData('X');
    } else if (button == 'Y') {
      sendData('Y');
    }
  }

  void onButtonReleased(String button) {
    setState(() {
      buttonStates[button] = false;
    });

    if (['UP', 'DOWN', 'LEFT', 'RIGHT'].contains(button)) {
      sendData('S');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void showBluetoothDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter out devices without a name
            final filteredResults = scanResults
                .where((result) => result.device.platformName.isNotEmpty)
                .toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.grey[50],
              title: Row(
                children: [
                  Icon(Icons.bluetooth, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text(
                    'Bluetooth Devices',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    if (isScanning)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Colors.blueAccent,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Scanning for devices...",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: filteredResults.isEmpty
                          ? Center(
                              child: Text(
                                isScanning
                                    ? "Searching nearby devices..."
                                    : "No devices found.",
                                style: TextStyle(color: const Color.fromARGB(255, 10, 10, 10)),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredResults.length,
                              separatorBuilder: (_, __) =>
                                  Divider(color: Colors.grey[300]),
                              itemBuilder: (context, index) {
                                final result = filteredResults[index];
                                final device = result.device;
                                final name = device.platformName;

                                return ListTile(
                                  leading: Icon(Icons.devices_other,
                                      color: Colors.blueAccent),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 75, 75, 75),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(device.remoteId.toString()),
                                  trailing: Text(
                                    '${result.rssi} dBm',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    // connectToDevice(device);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actionsPadding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isScanning ? Colors.redAccent : Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isScanning ? Icons.stop : Icons.search,
                    color: Colors.white,
                  ),
                  label: Text(
                    isScanning ? 'Stop Scan' : 'Start Scan',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    if (isScanning) {
                      stopScan();
                    } else {
                      startScan();
                      // Automatically stop after 10 seconds
                      Future.delayed(Duration(seconds: 10), () {
                        if (isScanning) {
                          stopScan();
                          setDialogState(() {});
                        }
                      });
                    }
                    setDialogState(() {});
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Helper connection function used above
  Future<void> connectToWifi(String ssid, String password, void Function(void Function()) setDialogState) async {
    // show connecting snackbar or update dialog state
    setDialogState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connecting to $ssid...')));

    try {
      // Choose the security type if you know it; WPA is common. If open network, omit password.
      final bool connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password.isNotEmpty ? password : null,
        joinOnce: true,
        security: password.isNotEmpty ? NetworkSecurity.WPA : NetworkSecurity.NONE,
      );

      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to $ssid')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect to $ssid')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error connecting: $e')));
    } finally {
      setDialogState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2C2E3A),
      body: SafeArea(
        child: Column(
          children: [
            // Bagian Header (Tombol Atas)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildTopButton(Icons.arrow_back, () {
                        Navigator.pop(context);
                      }),
                      SizedBox(width: 12),
                      _buildTopButton(Icons.wifi, () {
                        showWifiDialog();
                        print('WiFi button pressed');
                      }),
                      //     SizedBox(width: 12),
                      //     _buildTopButton(Icons.bluetooth, () {
                      //       showBluetoothDialog();
                      //     }),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        isConnected
                            ? (connectedDevice?.platformName ?? 'Connected')
                            : 'Disconnected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12),
                      _buildToggleSwitch(),
                    ],
                  ),
                ],
              ),
            ),
            // Bagian Kontrol Utama (DPad, Slider, Action Buttons)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 30), // Padding yang lebih seimbang
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Kiri: DPad
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: DPadWidget(
                              buttonStates: buttonStates,
                              onButtonPressed: onButtonPressed,
                              onButtonReleased: onButtonReleased,
                            ),
                          ),
                        ),

                        // Tengah: Speed Slider
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      200), // Batasi lebar slider di tengah
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Speed',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  SliderTheme(
                                    data: SliderThemeData(
                                      activeTrackColor: Color(0xFF8B0000),
                                      inactiveTrackColor: Color(0xFFD3D3D3),
                                      thumbColor: Color(
                                          0xFF8B0000), // Ganti warna thumb menjadi merah
                                      overlayColor:
                                          Color(0xFF8B0000).withOpacity(0.2),
                                      thumbShape: RoundSliderThumbShape(
                                        enabledThumbRadius: 12.0,
                                      ),
                                      trackHeight: 8.0,
                                    ),
                                    child: Slider(
                                      value: speedValue,
                                      min: 0,
                                      max: 100,
                                      divisions:
                                          100, // Tambahkan divisi untuk kontrol lebih baik
                                      label: speedValue.round().toString(),
                                      onChanged: (value) {
                                        setState(() {
                                          speedValue = value;
                                        });
                                        int speedInt = value.toInt();
                                        sendData('V$speedInt');
                                      },
                                    ),
                                  ),
                                  Text(
                                    '${speedValue.round()}%',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Kanan: Action Buttons
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: ActionButtonsWidget(
                              buttonStates: buttonStates,
                              onButtonPressed: onButtonPressed,
                              onButtonReleased: onButtonReleased,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: Colors.black,
          size: 26,
        ),
      ),
    );
  }

    Widget _buildToggleSwitch() {
      return GestureDetector(
        onTap: () {
          if (isConnected) {
            disconnectDevice();
          } else {
            showBluetoothDialog();
          }
        },
        child: Container(
          width: 58,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isConnected ? Color(0xFF34C759) : Color(0xFF8E8E93),
          ),
          padding: const EdgeInsets.all(3),
          child: AnimatedAlign(
            duration: Duration(milliseconds: 200),
            alignment: isConnected ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

class DPadWidget extends StatelessWidget {
  final Map<String, bool> buttonStates;
  final Function(String) onButtonPressed;
  final Function(String) onButtonReleased;

  const DPadWidget({
    required this.buttonStates,
    required this.onButtonPressed,
    required this.onButtonReleased,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, // Ukuran DPad sedikit diperbesar
      height: 180,
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: Size(180, 180), // Sesuaikan ukuran CustomPaint
              painter: DPadBackgroundPainter(),
            ),
          ),
          // Perhitungan posisi disesuaikan agar tetap berada di dalam Stack 180x180
          Positioned(
            top: 5,
            left: 70, // (180 - 40) / 2 = 70. 40 adalah lebar/tinggi DPadButton.
            child: DPadButton(
              icon: Icons.arrow_drop_up,
              isPressed: buttonStates['UP']!,
              onPressed: () => onButtonPressed('UP'),
              onReleased: () => onButtonReleased('UP'),
            ),
          ),
          Positioned(
            bottom: 5,
            left: 70,
            child: DPadButton(
              icon: Icons.arrow_drop_down,
              isPressed: buttonStates['DOWN']!,
              onPressed: () => onButtonPressed('DOWN'),
              onReleased: () => onButtonReleased('DOWN'),
            ),
          ),
          Positioned(
            left: 5,
            top: 70,
            child: DPadButton(
              icon: Icons.arrow_left,
              isPressed: buttonStates['LEFT']!,
              onPressed: () => onButtonPressed('LEFT'),
              onReleased: () => onButtonReleased('LEFT'),
            ),
          ),
          Positioned(
            right: 5,
            top: 70,
            child: DPadButton(
              icon: Icons.arrow_right,
              isPressed: buttonStates['RIGHT']!,
              onPressed: () => onButtonPressed('RIGHT'),
              onReleased: () => onButtonReleased('RIGHT'),
            ),
          ),
        ],
      ),
    );
  }
}

class DPadBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF8B0000)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final armWidth = 30.0; // Sedikit diperbesar dari 28
    final armLength = 70.0; // Sedikit diperbesar dari 60
    final cornerRadius = 15.0; // Sedikit diperbesar dari 12

    final path = Path();
    // Start top
    path.moveTo(centerX - armWidth, centerY - armLength);
    // Top right corner
    path.arcToPoint(
      Offset(centerX + armWidth, centerY - armLength),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(centerX + armWidth, centerY - armWidth);
    // Right arm start
    path.lineTo(centerX + armLength, centerY - armWidth);
    // Bottom right corner
    path.arcToPoint(
      Offset(centerX + armLength, centerY + armWidth),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(centerX + armWidth, centerY + armWidth);
    // Bottom arm start
    path.lineTo(centerX + armWidth, centerY + armLength);
    // Bottom left corner
    path.arcToPoint(
      Offset(centerX - armWidth, centerY + armLength),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(centerX - armWidth, centerY + armWidth);
    // Left arm start
    path.lineTo(centerX - armLength, centerY + armWidth);
    // Top left corner
    path.arcToPoint(
      Offset(centerX - armLength, centerY - armWidth),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(centerX - armWidth, centerY - armWidth);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DPadButton extends StatelessWidget {
  final IconData icon;
  final bool isPressed;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  // Ukuran tombol DPad diseragamkan
  final double size = 40.0;

  const DPadButton({
    required this.icon,
    required this.isPressed,
    required this.onPressed,
    required this.onReleased,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPressed ? Colors.white.withOpacity(0.3) : Colors.transparent,
          // Menggunakan BoxShape.circle untuk membuat bagian interaksi lebih intuitif
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class ActionButtonsWidget extends StatelessWidget {
  final Map<String, bool> buttonStates;
  final Function(String) onButtonPressed;
  final Function(String) onButtonReleased;

  const ActionButtonsWidget({
    required this.buttonStates,
    required this.onButtonPressed,
    required this.onButtonReleased,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, // Ukuran kontainer disesuaikan dengan DPad
      height: 180,
      child: Stack(
        children: [
          // Posisi X (Atas)
          Positioned(
            top: 5,
            left: 60, // (180 - 60) / 2 = 60
            child: ActionButton(
              label: 'X',
              isPressed: buttonStates['X']!,
              onPressed: () => onButtonPressed('X'),
              onReleased: () => onButtonReleased('X'),
            ),
          ),
          // Posisi Y (Kiri)
          Positioned(
            left: 5,
            top: 60, // (180 - 60) / 2 = 60
            child: ActionButton(
              label: 'Y',
              isPressed: buttonStates['Y']!,
              onPressed: () => onButtonPressed('Y'),
              onReleased: () => onButtonReleased('Y'),
            ),
          ),
          // Posisi A (Kanan)
          Positioned(
            right: 5,
            top: 60,
            child: ActionButton(
              label: 'A',
              isPressed: buttonStates['A']!,
              onPressed: () => onButtonPressed('A'),
              onReleased: () => onButtonReleased('A'),
            ),
          ),
          // Posisi B (Bawah)
          Positioned(
            bottom: 5,
            left: 60,
            child: ActionButton(
              label: 'B',
              isPressed: buttonStates['B']!,
              onPressed: () => onButtonPressed('B'),
              onReleased: () => onButtonReleased('B'),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final bool isPressed;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  final double size = 60.0;

  const ActionButton({
    required this.label,
    required this.isPressed,
    required this.onPressed,
    required this.onReleased,
  });

  // Function to return the SVG icon string based on the button label.
  String _getSvgIcon(String label) {
    switch (label) {
      case 'X':
        return '''
<svg xmlns="http://www.w3.org/2000/svg" width="33" height="33" viewBox="0 0 33 33" fill="none">
  <g clip-path="url(#clip0_48_111)" transform="rotate(-90 15 16.5)">
    <path d="M6.875 31.625C6.14565 31.625 5.44618 31.3353 4.93046 30.8195C4.41473 30.3038 4.125 29.6043 4.125 28.875V4.125C4.125 3.39565 4.41473 2.69618 4.93046 2.18046C5.44618 1.66473 6.14565 1.375 6.875 1.375H22C22.7293 1.375 23.4288 1.66473 23.9445 2.18046C24.4603 2.69618 24.75 3.39565 24.75 4.125V9.625L28.875 12.375V20.625L24.75 23.375V28.875C24.75 29.6043 24.4603 30.3038 23.9445 30.8195C23.4288 31.3353 22.7293 31.625 22 31.625H6.875Z" stroke="#9A0000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M9.625 16.5C9.625 19.5376 12.0874 22 15.125 22C18.1626 22 20.625 19.5376 20.625 16.5C20.625 13.4624 18.1626 11 15.125 11C12.0874 11 9.625 13.4624 9.625 16.5Z" stroke="#9A0000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</g>
  <defs>
    <clipPath id="clip0_48_111">
      <rect width="33" height="33" fill="white" transform="matrix(0 1 -1 0 33 0)"/>
    </clipPath>
  </defs>
</svg>
''';
      case 'Y':
        return '''
<svg xmlns="http://www.w3.org/2000/svg" width="37" height="39" viewBox="0 0 37 39" fill="none">
  <g clip-path="url(#clip0_48_91)" transform="rotate(-90 15 16.5)">
    <path d="M21.0283 1.87151V37.0854C21.0281 37.7494 20.5236 38.2416 19.9561 38.2416H2.51953C1.95197 38.2416 1.44751 37.7494 1.44727 37.0854V1.87151C1.44727 1.20727 1.95184 0.714279 2.51953 0.714279H19.9561C20.5237 0.714279 21.0283 1.20727 21.0283 1.87151Z" fill="white" stroke="#9A0000"/>
    <path d="M5.22651 10.7996C5.22651 14.298 7.91708 17.134 11.2361 17.134C14.555 17.134 17.2456 14.298 17.2456 10.7996C17.2456 7.30118 14.555 4.46518 11.2361 4.46518C7.91708 4.46518 5.22651 7.30118 5.22651 10.7996Z" fill="#9A0000"/>
    <path d="M5.22651 28.1542C5.22651 31.6525 7.91708 34.4886 11.2361 34.4886C14.555 34.4886 17.2456 31.6525 17.2456 28.1542C17.2456 24.6558 14.555 21.8198 11.2361 21.8198C7.91708 21.8198 5.22651 24.6558 5.22651 28.1542Z" fill="#9A0000"/>
    <path d="M8.49175 10.7996C8.49175 12.3971 9.72038 13.6921 11.236 13.6921C12.7516 13.6921 13.9802 12.3971 13.9802 10.7996C13.9802 9.20203 12.7516 7.90698 11.236 7.90698C9.72038 7.90698 8.49175 9.20203 8.49175 10.7996Z" fill="white"/>
    <path d="M8.49175 28.1542C8.49175 29.7517 9.72038 31.0467 11.236 31.0467C12.7516 31.0467 13.9802 29.7517 13.9802 28.1542C13.9802 26.5566 12.7516 25.2616 11.236 25.2616C9.72038 25.2616 8.49175 26.5566 8.49175 28.1542Z" fill="white"/>
    <path d="M18.7832 19.4769C18.7832 21.0744 20.0119 22.3694 21.5275 22.3694C23.0431 22.3694 24.2717 21.0744 24.2717 19.4769C24.2717 17.8793 23.0431 16.5843 21.5275 16.5843C20.0119 16.5843 18.7832 17.8793 18.7832 19.4769Z" fill="#9A0000"/>
    <path d="M31.1905 30.4478C31.1905 30.334 31.2332 30.2205 31.3181 30.1362C34.1366 27.3374 35.6885 23.5522 35.6885 19.4781C35.6885 15.404 34.1366 11.6193 31.3181 8.82009C31.1548 8.65827 31.1475 8.38729 31.301 8.21477C31.4545 8.04268 31.7116 8.03498 31.8753 8.19679C34.8583 11.1596 36.5007 15.166 36.5007 19.4781C36.5007 23.7907 34.8583 27.7971 31.8753 30.7595C31.712 30.9217 31.4549 30.9136 31.301 30.7415C31.2275 30.6585 31.1905 30.5532 31.1905 30.4478Z" fill="#9A0000"/>
    <path d="M28.4207 27.3481C28.4207 27.2342 28.4634 27.1208 28.5483 27.0364C30.5517 25.0471 31.6548 22.3626 31.6548 19.4782C31.6548 16.5941 30.5517 13.9096 28.5483 11.9194C28.3854 11.7576 28.3777 11.4862 28.5312 11.3141C28.6847 11.142 28.9418 11.1343 29.1055 11.2961C31.2734 13.4498 32.467 16.3557 32.467 19.4782C32.467 22.601 31.273 25.5065 29.1051 27.6593C28.9418 27.8215 28.6847 27.8134 28.5308 27.6413C28.4573 27.5587 28.4207 27.4534 28.4207 27.3481Z" fill="#9A0000"/>
    <path d="M25.7834 24.3969C25.7834 24.283 25.826 24.1695 25.9109 24.0852C27.1321 22.872 27.8047 21.2359 27.8047 19.4777C27.8047 17.7196 27.1321 16.0834 25.9109 14.8702C25.748 14.7088 25.7403 14.437 25.8938 14.2649C26.0473 14.0928 26.3044 14.0851 26.4681 14.2469C27.8538 15.6232 28.6169 17.4807 28.6169 19.4773C28.6169 21.4735 27.8538 23.3309 26.4681 24.7076C26.3048 24.8699 26.0477 24.8618 25.8938 24.6897C25.8199 24.6079 25.7834 24.5022 25.7834 24.3969Z" fill="#9A0000"/>
  </g>
  <defs>
    <clipPath id="clip0_48_91">
      <rect width="39" height="37" fill="white" transform="matrix(0 1 -1 0 37 0)"/>
    </clipPath>
  </defs>
</svg>
''';
      case 'A':
        return '''
<svg xmlns="http://www.w3.org/2000/svg" width="35" height="35" viewBox="0 0 35 35" fill="none" >
  <path transform="rotate(-90 15 16.5)" d="M4.375 16.0417C8.02083 16.0417 8.02083 18.9583 11.6667 18.9583M4.375 23.3333C8.02083 23.3333 8.02083 26.25 11.6667 26.25M23.3333 27.7083L18.9583 26.5417C18.5526 26.4589 18.1872 26.2406 17.9222 25.9225C17.6571 25.6044 17.5082 25.2056 17.5 24.7917V10.2083C17.5082 9.79439 17.6571 9.39556 17.9222 9.07749C18.1872 8.75943 18.5526 8.54106 18.9583 8.45834L23.3333 7.29167M4.375 8.75C8.02083 8.75 8.02083 11.6667 11.6667 11.6667M30.625 30.625C30.625 31.0118 30.4714 31.3827 30.1979 31.6562C29.9244 31.9297 29.5534 32.0833 29.1667 32.0833H26.25C25.4765 32.0833 24.7346 31.776 24.1876 31.2291C23.6406 30.6821 23.3333 29.9402 23.3333 29.1667V5.83334C23.3333 5.05979 23.6406 4.31792 24.1876 3.77094C24.7346 3.22396 25.4765 2.91667 26.25 2.91667H29.1667C29.5534 2.91667 29.9244 3.07032 30.1979 3.34381C30.4714 3.6173 30.625 3.98823 30.625 4.37501V30.625Z" stroke="#9A0000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';
      case 'B':
        return '''
<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 30 30" fill="none">
  <g clip-path="url(#clip0_48_108)" transform="rotate(-90 15 16.5)">
    <path d="M17.0294 23.1111H14.5967C12.3385 23.1111 10.1727 22.214 8.57593 20.6172C6.97913 19.0204 6.08205 16.8547 6.08205 14.5965M6.08205 14.5965C6.08205 12.3383 6.97913 10.1726 8.57593 8.57575C10.1727 6.97895 12.3385 6.08188 14.5967 6.08188H17.0294M6.08205 14.5965H1.21655M1.21655 9.731V19.462M27.9768 14.5965C27.9768 13.6287 27.5923 12.7005 26.908 12.0162C26.2237 11.3318 25.2955 10.9474 24.3277 10.9474H14.5967C13.6289 10.9474 12.7007 11.3318 12.0164 12.0162C11.332 12.7005 10.9476 13.6287 10.9476 14.5965C10.9476 15.5643 11.332 16.4925 12.0164 17.1768C12.7007 17.8612 13.6289 18.2456 14.5967 18.2456H24.3277C25.2955 18.2456 26.2237 17.8612 26.908 17.1768C27.5923 16.4925 27.9768 15.5643 27.9768 14.5965Z" stroke="#9A0000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
  <defs>
    <clipPath id="clip0_48_108">
      <rect width="29.193" height="29.193" fill="white" transform="matrix(0 1 -1 0 29.1931 0)"/>
    </clipPath>
  </defs>
</svg>
''';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPressed
              ? Color(0xFF8B0000).withOpacity(0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Color(0xFF8B0000),
            width: 3,
          ),
        ),
        child: Center(
          child: SvgPicture.string(
            _getSvgIcon(label),
            // Sesuaikan ukuran SVG agar lebih pas di dalam tombol 60x60
            width: label == 'Y' ? 30 : 28,
            height: label == 'Y' ? 30 : 28,
          ),
        ),
      ),
    );
  }
}
