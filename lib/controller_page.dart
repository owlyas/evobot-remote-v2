import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:io';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // Import ini
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

// UUIDs for UART communication
const String targetServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const String rxCharUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
const String txCharUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

class ControllerPage extends StatefulWidget {
  const ControllerPage({Key? key}) : super(key: key);

  @override
  ControllerPageState createState() => ControllerPageState();
}

class ControllerPageState extends State<ControllerPage> {
  String batteryLevel = "--"; // Default saat belum ada data
  String? connectedWifiSSID;  // Menyimpan nama Wi-Fi yang terhubung
  bool isConnected = false;
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? txCharacteristic;
  BluetoothCharacteristic? rxCharacteristic;
  StreamSubscription<List<int>>? txSubscription;
  Completer<String>? _responseCompleter;
  bool isWifiScanning = false;
  List<WifiNetwork> wifiNetworks = [];
  Timer? stopTimer;
  Timer? _dialogStopScanTimer; // used by Bluetooth dialog
  Timer? _reconnectTimer;
  List<ScanResult> scanResults = [];
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  String? _lastErrorMessage;
  DateTime? _lastErrorTime;
  bool dpadEnabled = true;
  late final WebViewController _videoController;

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

  // Throttle state for scanResults updates
  DateTime _lastScanUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _scanUpdateInterval = Duration(milliseconds: 300);

  // Default scan timeout (seconds)
  static const int _scanTimeoutSec = 3;

  // Reconnect/backoff config
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _maxBackoff = Duration(seconds: 20);
  bool _autoReconnectEnabled = true; // toggle if you want auto reconnect

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _videoController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(
        Uri.parse('http://10.42.0.1:8000'),
      );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    stopScan();
    super.dispose();
  }
  
  // -------------------------
  // Wi-Fi scanning (with permissions & safe timer)
  // -------------------------
  Future<void> startWifiScan() async {
    // Request location permission (required on modern Android for Wi-Fi scanning)
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      showError('Location permission is required for WiFi scanning.');
      return;
    }

    setStateIfMounted(() => isWifiScanning = true);

    try {
      final List<WifiNetwork>? results = await WiFiForIoTPlugin.loadWifiList();

      setStateIfMounted(() {
        wifiNetworks = results ?? [];
        // keep isWifiScanning true until timer fires or user stops manually
      });

      // Auto stop after _scanTimeoutSec seconds if still scanning
      stopTimer?.cancel();
      stopTimer = Timer(Duration(seconds: _scanTimeoutSec), () {
        if (mounted && isWifiScanning) {
          stopWifiScan();
        }
      });
    } catch (e) {
      print('Error during WiFi scan: $e');
      setStateIfMounted(() => isWifiScanning = false);
      showError('Failed to scan WiFi: $e');
    }
  }

  void stopWifiScan() {
    stopTimer?.cancel();
    // Note: depending on plugin, there might not be an explicit stop call.
    // We at least clear the UI scanning state.
    setStateIfMounted(() => isWifiScanning = false);
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

  Future<void> checkEvobotConnection(BuildContext context) async {
    debugPrint("🔍 [WiFi CHECK] Starting Evobot connection check");

    final connectivity = await Connectivity().checkConnectivity();
    debugPrint("📡 [Connectivity] Result = $connectivity");

    final isWifi = connectivity.contains(ConnectivityResult.wifi);

    if (!isWifi) {
      debugPrint("❌ [WiFi CHECK] Not connected to Wi-Fi");

      _showResultDialog(
        context,
        success: false,
        message: "Device is not connected to Wi-Fi.",
      );
      return;
    }

    debugPrint("✅ [WiFi CHECK] Wi-Fi detected");

    final info = NetworkInfo();
    String? ssid = await info.getWifiName();

    debugPrint("📶 [WiFi CHECK] Raw SSID = $ssid");

    final cleanSsid = ssid
        ?.replaceAll('"', '')
        .trim()
        .toLowerCase();

    debugPrint("🧹 [WiFi CHECK] Clean SSID = $cleanSsid");

    if (cleanSsid == 'evobot') {
      debugPrint("✅ [WiFi CHECK] Connected to EVOBOT");

      _showResultDialog(
        context,
        success: true,
        message: "Connected to Evobot Wi-Fi.",
      );
    } else {
      debugPrint("❌ [WiFi CHECK] Wrong SSID");

      _showResultDialog(
        context,
        success: false,
        message: "Connected to \"$ssid\", not Evobot.",
      );
    }
  }

  void _showResultDialog(
    BuildContext context, {
    required bool success,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(success ? "Connected" : "Not Connected"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void showWifiDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.grey[50],

          title: Row(
            children: const [
              Icon(Icons.wifi, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text(
                'Wi-Fi Connection',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // HOW TO BOX
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "How to Connect to Evobot",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "1. Turn on Raspberry Pi (Evobot).\n"
                          "2. Open Wi-Fi settings on your phone.\n"
                          "3. Connect to Wi-Fi named \"Evobot\".\n"
                          "4. Return to this app.\n"
                          "5. Press the button below to check connection.",
                          style: TextStyle(fontSize: 15, 
                          color: Color.fromARGB(255, 70, 69, 69)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text("Check Evobot Connection"),
                      onPressed: () {
                        checkEvobotConnection(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
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
  }

  Future<void> checkWifiConnection(BuildContext context) async {
    final result = await Connectivity().checkConnectivity();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result == ConnectivityResult.wifi
                  ? Icons.check_circle
                  : Icons.error,
              color: result == ConnectivityResult.wifi
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              result == ConnectivityResult.wifi
                  ? "Connected"
                  : "Not Connected",
            ),
          ],
        ),
        content: Text(
          result == ConnectivityResult.wifi
              ? "Your phone is connected to a Wi-Fi network.\n"
                "Make sure it is the Raspberry Pi Wi-Fi."
              : "Your phone is not connected to Wi-Fi.\n"
                "Please connect to the Raspberry Pi Wi-Fi first.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // -------------------------
  // Bluetooth scanning (with permissions & safe timer)
  // -------------------------
  Future<void> startScan() async {
    // Request location permission for BLE scan on Android
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      showError('Location permission is required for Bluetooth scanning.');
      return;
    }

    // Prevent double start
    if (isScanning) return;

    setStateIfMounted(() {
      isScanning = true;
      scanResults = [];
    });

    // Cancel any previous subscription
    scanSubscription?.cancel();

    // Start scanning
    try {
      // Ensure any previous scan is stopped first
      await FlutterBluePlus.stopScan().catchError((_) {});
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: _scanTimeoutSec),
        androidUsesFineLocation: true,
      );

      // Subscribe to scan results and throttle UI updates
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now();
        if (now.difference(_lastScanUpdate) >= _scanUpdateInterval) {
          _lastScanUpdate = now;
          setStateIfMounted(() {
            scanResults = results;
          });
        } else {
          // still update internal list so we always have latest for tapping,
          // but avoid calling setState too often
          scanResults = results;
        }
      });

      // Also set a stop timer as a safeguard (in case plugin timeout behaves differently)
      stopTimer?.cancel();
      stopTimer = Timer(Duration(seconds: _scanTimeoutSec), () async {
        await stopScan().catchError((_) {});
      });
    } catch (e) {
      print('Error starting BLE scan: $e');
      showError('Failed to start Bluetooth scan: $e');
      setStateIfMounted(() => isScanning = false);
    }
  }

  Future<void> stopScan() async {
    try {
      stopTimer?.cancel();
      await FlutterBluePlus.stopScan().catchError((e) {
        // plugin may throw if not scanning — ignore silently
        print('stopScan: plugin stop error: $e');
      });

      // Cancel the subscription
      scanSubscription?.cancel();
      scanSubscription = null;

      setStateIfMounted(() {
        isScanning = false;
      });
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  // -------------------------
  // Connect / disconnect device (with connection subscription)
  // -------------------------
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Clean previous state
      await txSubscription?.cancel();
      txSubscription = null;
      rxCharacteristic = null;
      txCharacteristic = null;

      // Connect
      await device.connect(
        timeout: Duration(seconds: _scanTimeoutSec),
        autoConnect: false,
      );

      connectedDevice = device;
      setStateIfMounted(() {
        isConnected = true;
      });

      print('✅ Connected! Discovering services...');
      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == targetServiceUUID) {
          print('✅ Target service found');

          for (final c in service.characteristics) {
            // RX = phone → device
            if (c.uuid.toString().toLowerCase() == rxCharUUID) {
              rxCharacteristic = c;
              print('✅ RX Characteristic found');
            }

            // TX = device → phone
            if (c.uuid.toString().toLowerCase() == txCharUUID) {
              txCharacteristic = c;

              await c.setNotifyValue(true);

              // 🔔 LISTEN to notifications
              txSubscription = c.value.listen((value) {
                final response = String.fromCharCodes(value).trim();
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hapus notif lama biar gak numpuk
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   SnackBar(
                  //     content: Text("Robot Kirim: $response"), // <--- Ini yang bikin muncul di layar
                  //     backgroundColor: Colors.blue,
                  //     duration: const Duration(milliseconds: 800), // Muncul sebentar (0.8 detik)
                  //   ),
                  // );
                }

                // print('DEBUG TERIMA: "$response"');
                // print('📥 TX received: $response');

                // if (response == "SELESAI") {
                // print("SELESAI = DITERIMA");
                
                // setStateIfMounted(() {
                //   Map<String, bool> updatedStates = Map.from(buttonStates);
                //   updatedStates['X'] = false;
                //   buttonStates = updatedStates;
                //   });

                //   print("✅ UI HARUSNYA UPDATE SEKARANG");
                // }

                if (response == "SELESAI") {
                   _handleSelesaiMessage(); // <--- Panggil fungsi void di sini
                }
                if (response.startsWith("BAT:")) {
                  setStateIfMounted(() {
                    batteryLevel = response.split(":")[1]; 
                  });
                }

                // Complete waiting command if any
                if (_responseCompleter != null &&
                    !_responseCompleter!.isCompleted) {
                  _responseCompleter!.complete(response);
                }
              });

              print('✅ TX Characteristic found & listening');
            }
          }
        }
      }

      // Validate required characteristics
      if (rxCharacteristic == null || txCharacteristic == null) {
        throw Exception('Required BLE characteristics not found');
      }

      return true;

    } catch (e) {
      print('❌ Error connecting: $e');
      showError('Connection failed: $e');

      await txSubscription?.cancel();
      txSubscription = null;

      return false;
    }
  }

  // Fungsi khusus untuk menangani pesan "SELESAI"
  void _handleSelesaiMessage() {
    print("🤖 Robot mengirim: SELESAI");

    setStateIfMounted(() {
      // Logic mematikan tombol X
      Map<String, bool> updatedStates = Map.from(buttonStates);
      updatedStates['X'] = false; 
      buttonStates = updatedStates;
    });

    print("✅ Status tombol X di-reset menjadi OFF");
  }

  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        // Cancel connection subscription first
        connectionSubscription?.cancel();
        connectionSubscription = null;

        await connectedDevice!.disconnect().catchError((e) {
          print('disconnect() warning: $e');
        });

        setStateIfMounted(() {
          isConnected = false;
          connectedDevice = null;
          txCharacteristic = null;
          rxCharacteristic = null;
          batteryLevel = "--"; 
          buttonStates.updateAll((key, value) => false);
        });

        showSuccess('Bluetooth Disconnected');
      } catch (e) {
        print('Error disconnecting: $e');
        showError('Error during disconnect: $e');
      }
    }
  }

  // -------------------------
  // Exponential backoff reconnect helper
  // -------------------------
  void _attemptReconnect(BluetoothDevice device) {
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      print('Max reconnect attempts reached ($_reconnectAttempts). Aborting.');
      _reconnectAttempts = 0;
      return;
    }

    final int backoffSec = (1 << (_reconnectAttempts - 1)); // 1,2,4,8...
    final Duration delay = Duration(seconds: backoffSec).compareTo(_maxBackoff) > 0
        ? _maxBackoff
        : Duration(seconds: backoffSec);

    print('Reconnect attempt #$_reconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!mounted) return;
      print('Attempting reconnect #$_reconnectAttempts...');
      final success = await connectToDevice(device);
      if (!success) {
        // schedule next attempt
        _attemptReconnect(device);
      } else {
        _reconnectAttempts = 0;
      }
    });
  }

  // -------------------------
  // Send data safely
  // -------------------------
  Future<void> sendData(String command) async {
    final state = await connectedDevice!.connectionState.first;
    if (state != BluetoothConnectionState.connected) {
      setState(() => isConnected = false);
      showError('Bluetooth disconnected');
      return;
    }

    const moveCommands = {'F', 'B', 'L', 'R', 'S'};
    const disableCommands = {'001', '002', '003', '004', '022'};

    try {
      // 🔒 Disable DPad
      if (disableCommands.contains(command)) {
        setState(() => dpadEnabled = false);
      }

      // 🚗 Movement (no wait)
      if (moveCommands.contains(command)) {
        await rxCharacteristic!.write(
          command.codeUnits,
          withoutResponse: false,
        );
        return;
      }

      final completer = Completer<void>();
      late StreamSubscription sub;

      sub = txCharacteristic!.lastValueStream.listen((value) {
        final response = String.fromCharCodes(value).trim();

        // 🔄 Re-enable on STOP
        if (response == 'STOP') {
          setState(() => dpadEnabled = true);
        }

        if (response == 'OK' && !completer.isCompleted) {
          completer.complete();
        }
      });

      await rxCharacteristic!.write(
        command.codeUnits,
        withoutResponse: false,
      );

      await completer.future.timeout(const Duration(seconds: 2));
      await sub.cancel();

    } catch (e) {
      setState(() => dpadEnabled = true); // safety
      showError('Command failed');
    }
  }
  
  void onButtonPressed(String button) {
    if (!isConnected) return;

    setState(() {
      buttonStates[button] = true;
    });

    final command = switch (button) {
      'UP' => 'F',
      'DOWN' => 'B',
      'LEFT' => 'L',
      'RIGHT' => 'R',
      _ => null,
    };

    if (command != null) {
      sendData(command);
      print(command);
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

  // -------------------------
  // Helpers
  // -------------------------
  /// Safe setState wrapper (checks mounted)
  void setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void showError(String message) {
    if (!mounted) return;

    final now = DateTime.now();

    // 🧠 Block duplicate errors within 2 seconds
    if (_lastErrorMessage == message &&
        _lastErrorTime != null &&
        now.difference(_lastErrorTime!) < const Duration(seconds: 2)) {
      return;
    }

    _lastErrorMessage = message;
    _lastErrorTime = now;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // -------------------------
  // Dialogs / UI helpers
  // -------------------------
  /// Shows Bluetooth devices and scanning controls.
  /// Uses a local Timer to auto-stop scanning; the timer is cancelled when the dialog closes.
  void showBluetoothDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          // Filter devices with a name
          final filteredResults = scanResults.where((r) => r.device.platformName.isNotEmpty).toList();

          // Helper to start/stop scans and keep dialog timer
          Future<void> _startScanForDialog() async {
            await startScan();
            // Cancel any previous dialog timer
            _dialogStopScanTimer?.cancel();
            _dialogStopScanTimer = Timer(Duration(seconds: _scanTimeoutSec), () {
              if (mounted) {
                stopScan();
                setDialogState(() {}); // refresh dialog UI
              }
            });
            setDialogState(() {}); // update UI after starting
          }

          Future<void> _stopScanForDialog() async {
            // 1️⃣ Stop BLE scan
            await FlutterBluePlus.stopScan().catchError((_) {});

            // 2️⃣ Cancel scan subscription
            await scanSubscription?.cancel();
            scanSubscription = null;

            // 3️⃣ Cancel dialog timer
            _dialogStopScanTimer?.cancel();
            _dialogStopScanTimer = null;

            // 4️⃣ Update BOTH dialog + page state
            if (mounted) {
              setState(() {
                isScanning = false;
              });
            }

            // 5️⃣ Refresh dialog UI
            setDialogState(() {});
          }
          return PopScope(
            canPop: true, // allow back button / gesture
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                // ✅ cleanup when dialog is popped
                _dialogStopScanTimer?.cancel();
              }
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              content: SizedBox(
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
                                style: TextStyle(
                                  color: Color.fromARGB(255, 10, 10, 10),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredResults.length,
                              separatorBuilder: (_, __) =>
                                  Divider(color: Colors.grey[300]),
                              itemBuilder: (context, index) {
                                final result = filteredResults[index];
                                final device = result.device;

                                return ListTile(
                                  leading: Icon(
                                    Icons.devices_other,
                                    color: Colors.blueAccent,
                                  ),
                                  title: Text(
                                    device.platformName,
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 75, 75, 75),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(device.remoteId.toString()),
                                  trailing: Text(
                                    '${result.rssi} dBm',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  onTap: () async {
                                    // Close device list dialog
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }

                                    _dialogStopScanTimer?.cancel();

                                    // Show connecting dialog
                                    late BuildContext connectingDialogContext;
                                    showDialog(
                                      context: this.context,
                                      barrierDismissible: false,
                                      builder: (ctx) {
                                        connectingDialogContext = ctx;
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          content: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Row(
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    'Connecting to ${device.platformName}...',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                    final ok = await connectToDevice(device);

                                    if (mounted &&
                                        Navigator.canPop(connectingDialogContext)) {
                                      Navigator.pop(connectingDialogContext);
                                    }

                                    if (!mounted) return;

                                    ok
                                        ? showSuccess(
                                            'Connected to ${device.platformName}')
                                        : showError(
                                            'Failed to connect to ${device.platformName}');
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
                  onPressed: () async {
                    if (isScanning) {
                      _stopScanForDialog();
                    } else {
                      await _startScanForDialog();
                    }
                    setDialogState(() {});
                  },
                ),
                TextButton(
                  onPressed: () {
                    _dialogStopScanTimer?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Close',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          );
        });
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
        setStateIfMounted(() {
          connectedWifiSSID = ssid;
        });
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

  void onToggle(String key) {

    if (key == 'Y' && buttonStates['Y'] == true) {
      sendData("YisOFF"); // <--- Kirim pesan saat dimatikan
    }

    if (key == 'B' && buttonStates['B'] == true) {
      sendData("BisOFF"); // <--- Kirim pesan saat dimatikan
      }

    setState(() {
      buttonStates[key] = !buttonStates[key]!;
    });

    // if (buttonStates[key] == true) {
    //   sendData("${key}isON");   // Example: Yon
    // } else {
    //   sendData("${key}isOFF");  // Example: Yoff
    // }
  }
  void showCameraDialog() {
   
    final List<Map<String, String>> voiceList = [
      {"label": "Forward Green", "cmd": "011"},
      {"label": "Forward Yellow", "cmd": "012"},
      {"label": "Forward Red", "cmd": "013"},
      {"label": "Green Search", "cmd": "014"}, // Contoh item ke-4
     
    ];

    showDialog(
      context: context, 
      builder: (_) {
        return AlertDialog(
          title: const Text("Camera Streaming Options"),
          contentPadding: const EdgeInsets.only(top: 20, bottom: 20), 
          
          content: SizedBox(
            width: 320, 
            height: 100,

            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24), 
              shrinkWrap: true, 
              physics: const BouncingScrollPhysics(), 
              
              itemCount: voiceList.length,
              separatorBuilder: (context, index) => const Divider(), 
              
              itemBuilder: (context, index) {
                final item = voiceList[index];
                bool isStop = item['cmd'] == 'STOP';

                return ListTile(
                  
                  title: Text(
                    item['label']!,
                    style: TextStyle(
                      color: const Color.fromARGB(221, 255, 255, 255),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    sendData(item['cmd']!);
                    if (buttonStates['X'] == false) {
                      onToggle('X'); 
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
  void showVoiceDialog() {
   final List<Map<String, String>> voiceList = [
      {"label": "VO OPTION 1", "cmd": "001"},
      {"label": "VO OPTION 2", "cmd": "002"},
      {"label": "VO OPTION 3", "cmd": "003"},
      {"label": "VO OPTION 4", "cmd": "004"}, // Contoh item ke-4
     
    ];

    showDialog(
      context: context, 
      builder: (_) {
        return AlertDialog(
          title: const Text("Voice Options"),
          contentPadding: const EdgeInsets.only(top: 20, bottom: 20), 
          
          content: SizedBox(
            width: 320, 
            height: 100,
            
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24), 
              shrinkWrap: true, 
              physics: const BouncingScrollPhysics(), 
              
              itemCount: voiceList.length,
              separatorBuilder: (context, index) => const Divider(), 
              
              itemBuilder: (context, index) {
                final item = voiceList[index];
                bool isStop = item['cmd'] == 'STOP';

                return ListTile(
                  
                  title: Text(
                    item['label']!,
                    style: TextStyle(
                      color: const Color.fromARGB(221, 255, 255, 255),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    sendData(item['cmd']!);
                    if (buttonStates['B'] == false) {
                      onToggle('B'); 
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

void showUltrasonicDialog() {
   final List<Map<String, String>> voiceList = [
      {"label": "Obstacle Detection", "cmd": "021"},
      {"label": "Auto Drive", "cmd": "022"},
    ];

    showDialog(
      context: context, 
      builder: (_) {
        return AlertDialog(
          title: const Text("Ultrasonic Options"),
          contentPadding: const EdgeInsets.only(top: 20, bottom: 20), 
          
          content: SizedBox(
            width: 320, 
            height: 100,
            
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24), 
              shrinkWrap: true, 
              physics: const BouncingScrollPhysics(), 
              
              itemCount: voiceList.length,
              separatorBuilder: (context, index) => const Divider(), 
              
              itemBuilder: (context, index) {
                final item = voiceList[index];
                bool isStop = item['cmd'] == 'STOP';

                return ListTile(
                  
                  title: Text(
                    item['label']!,
                    style: TextStyle(
                      color: const Color.fromARGB(221, 255, 255, 255),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    sendData(item['cmd']!);
                    if (buttonStates['Y'] == false) {
                      onToggle('Y'); 
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void disableDPadButtons() {
    setState(() {
      buttonStates['UP'] = false;
      buttonStates['DOWN'] = false;
      buttonStates['LEFT'] = false;
      buttonStates['RIGHT'] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2E3A),
      // 1. Ganti SafeArea langsung dengan Stack agar kita bisa menumpuk layer
      body: Stack(
        children: [
          // -----------------------------------------------------------
          // LAYER 1: UI Controller Utama (Background)
          // -----------------------------------------------------------
          SafeArea(
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
                          const SizedBox(width: 12),
                          _buildTopButton(Icons.wifi, () {
                            showWifiDialog();
                          }),
                          if (connectedWifiSSID != null) 
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Wi-Fi",
                                    style: TextStyle(color: Colors.white54, fontSize: 10),
                                  ),
                                  Text(
                                    connectedWifiSSID!,
                                    style: const TextStyle(
                                      color: Colors.greenAccent, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24)
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  // Ganti icon berdasarkan level baterai (simple logic)
                                  (int.tryParse(batteryLevel) ?? 0) > 20 
                                      ? Icons.battery_std 
                                      : Icons.battery_alert, 
                                  color: (int.tryParse(batteryLevel) ?? 0) < 20 && batteryLevel != "--"
                                      ? Colors.redAccent 
                                      : Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$batteryLevel%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isConnected
                                ? (connectedDevice?.platformName ?? 'Connected')
                                : 'Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                            horizontal: 20, vertical: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Kiri: DPad
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: DPadWidget(
                                  key: ValueKey(dpadEnabled), // 🔥 forces rebuild on lock change
                                  locked: !dpadEnabled,
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
                                  constraints:
                                      const BoxConstraints(maxWidth: 200),
                                      padding: const EdgeInsets.only(top: 40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Speed',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SliderTheme(
                                        data: SliderThemeData(
                                          activeTrackColor:
                                              const Color(0xFF8B0000),
                                          inactiveTrackColor:
                                              const Color(0xFFD3D3D3),
                                          thumbColor: const Color(0xFF8B0000),
                                          overlayColor: const Color(0xFF8B0000)
                                              .withOpacity(0.2),
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                            enabledThumbRadius: 12.0,
                                          ),
                                          trackHeight: 8.0,
                                        ),
                                        child: Slider(
                                          value: speedValue,
                                          min: 0,
                                          max: 100,
                                          divisions: 100,
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
                                        style: const TextStyle(
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
                                  onToggle: onToggle,
                                  onVoicePressed: showVoiceDialog,
                                  onCameraPressed: showCameraDialog,
                                  onUltrasonicPressed: showUltrasonicDialog,    
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

          // -----------------------------------------------------------
          // LAYER 2: Floating Video Player (Paling Atas)
          // -----------------------------------------------------------
          _buildFloatingVideo(),
        ],
      ),
    );
  }

  Widget _buildFloatingVideo() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: Stack(
              children: [
                // ---------------- VIDEO WEBVIEW ----------------
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: WebViewWidget(
                    controller: _videoController,
                  ),
                ),

                // ---------------- DEBUG OVERLAY ----------------
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "📹 Stream: http://10.42.0.1:8000",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _soundTile(BuildContext context, String title, String command) {
    return ListTile(
      leading: const Icon(Icons.play_arrow, color: Colors.blueAccent),
      title: Text(title),
      trailing: const Icon(Icons.volume_up),
      onTap: () async {
        Navigator.pop(context);

        await sendData(command); // 🔥 uses your existing logic
      },
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 58,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isConnected
                ? const Color(0xFF34C759) // 🟢 connected
                : const Color(0xFFB0B0B0), // ⚪ gray when disconnected
          ),
          padding: const EdgeInsets.all(3),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment:
                isConnected ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected
                    ? Colors.white
                    : Colors.grey.shade300, // ⚪ gray knob
                boxShadow: isConnected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [], // ❌ no shadow when disconnected
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
  final bool locked; // 🔒 NEW

  const DPadWidget({
    super.key,
    required this.buttonStates,
    required this.onButtonPressed,
    required this.onButtonReleased,
    this.locked = false, // 🔓 default unlocked
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: const Size(180, 180),
              painter: DPadBackgroundPainter(),
            ),
          ),

          // 🔼 UP
          Positioned(
            top: 5,
            left: 55,
            child: DPadButton(
              icon: Icons.arrow_drop_up,
              isPressed: buttonStates['UP']!,
              enabled: !locked, // 🔒
              onPressed: () => onButtonPressed('UP'),
              onReleased: () => onButtonReleased('UP'),
            ),
          ),

          // 🔽 DOWN
          Positioned(
            bottom: 5,
            left: 55,
            child: DPadButton(
              icon: Icons.arrow_drop_down,
              isPressed: buttonStates['DOWN']!,
              enabled: !locked,
              onPressed: () => onButtonPressed('DOWN'),
              onReleased: () => onButtonReleased('DOWN'),
            ),
          ),

          // ◀ LEFT
          Positioned(
            left: 5,
            top: 55,
            child: DPadButton(
              icon: Icons.arrow_left,
              isPressed: buttonStates['LEFT']!,
              enabled: !locked,
              onPressed: () => onButtonPressed('LEFT'),
              onReleased: () => onButtonReleased('LEFT'),
            ),
          ),

          // ▶ RIGHT
          Positioned(
            right: 5,
            top: 55,
            child: DPadButton(
              icon: Icons.arrow_right,
              isPressed: buttonStates['RIGHT']!,
              enabled: !locked,
              onPressed: () => onButtonPressed('RIGHT'),
              onReleased: () => onButtonReleased('RIGHT'),
            ),
          ),

          // 🔒 Optional lock overlay
          if (locked)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !locked,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: locked ? 1.0 : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock,
                        size: 36,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
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
  final bool enabled; // 🔹 NEW
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const DPadButton({
    super.key,
    required this.icon,
    required this.isPressed,
    required this.onPressed,
    required this.onReleased,
    this.enabled = true, // 🔹 default enabled
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer( // 🔹 HARD block touch when disabled
      ignoring: !enabled,
      child: Opacity( // 🔹 visual feedback
        opacity: enabled ? 1.0 : 0.45,
        child: Listener(
          behavior: HitTestBehavior.opaque,

          // 🟢 Finger touches screen
          onPointerDown: enabled ? (_) => onPressed() : null,

          // 🔴 Finger lifts
          onPointerUp: enabled ? (_) => onReleased() : null,

          // ⚠️ Safety
          onPointerCancel: enabled ? (_) => onReleased() : null,

          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !enabled
                  ? Colors.white.withOpacity(0.05)
                  : isPressed
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 36,
              color: enabled
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionButtonsWidget extends StatelessWidget {
  final Map<String, bool> buttonStates;
  final Function(String) onToggle;   // <-- NEW: toggle function
  final VoidCallback onVoicePressed;
  final VoidCallback onCameraPressed;
  final VoidCallback onUltrasonicPressed;

  const ActionButtonsWidget({
    required this.buttonStates,
    required this.onToggle,
    required this.onVoicePressed,
    required this.onCameraPressed,
    required this.onUltrasonicPressed,  
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      child: Stack(
        children: [
          // X button (Camera)
          Positioned(
            top: 5,
            left: 60,
            child: ActionButton(
              label: 'X',
              isOn: buttonStates['X']!,
              isLocked: false,
             onToggle: () {
                if (buttonStates['X'] == false) {
                  onCameraPressed();
                } else {
                  onToggle('X'); 
                }
              },
            ),
          ),

          // Y button (Ultrasonik)
          Positioned(
            left: 5,
            top: 60,
            child: ActionButton(
              label: 'Y',
              isOn: buttonStates['Y']!,
              isLocked: false,

              onToggle: () {
                if (buttonStates['Y'] == false) {
                  onUltrasonicPressed();

                } else {
                  onToggle('Y'); 
                }
              },
            ),
          ),

          // A button (Asap)
          Positioned(
            right: 5,
            top: 60,
            child: ActionButton(
              label: 'A',
              isOn: buttonStates['A']!,
              isLocked: false,
              onToggle: () => onToggle('A'),
            ),
          ),

          // B button (Mic)
          Positioned(
            bottom: 5,
            left: 60,
            child: ActionButton(
              label: 'B',
              isOn: buttonStates['B']!,
              isLocked: false,

              onToggle: () {
                if (buttonStates['B'] == false) {
                  onVoicePressed();
                   
                } else {
                  onToggle('B'); 
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}


class ActionButton extends StatelessWidget {
  final String label;
  final bool isOn;                     // <-- toggle state
  final VoidCallback onToggle;         // <-- toggle callback
  final bool isLocked;                 // <-- if true, button is not toggleable
  final double size = 60.0;

  const ActionButton({
    super.key,
    required this.label,
    required this.isOn,
    required this.isLocked,
    required this.onToggle,
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
''';;
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
''';;
      case 'A':
        return '''
<svg xmlns="http://www.w3.org/2000/svg" width="35" height="35" viewBox="0 0 35 35" fill="none" >
  <path transform="rotate(-90 15 16.5)" d="M4.375 16.0417C8.02083 16.0417 8.02083 18.9583 11.6667 18.9583M4.375 23.3333C8.02083 23.3333 8.02083 26.25 11.6667 26.25M23.3333 27.7083L18.9583 26.5417C18.5526 26.4589 18.1872 26.2406 17.9222 25.9225C17.6571 25.6044 17.5082 25.2056 17.5 24.7917V10.2083C17.5082 9.79439 17.6571 9.39556 17.9222 9.07749C18.1872 8.75943 18.5526 8.54106 18.9583 8.45834L23.3333 7.29167M4.375 8.75C8.02083 8.75 8.02083 11.6667 11.6667 11.6667M30.625 30.625C30.625 31.0118 30.4714 31.3827 30.1979 31.6562C29.9244 31.9297 29.5534 32.0833 29.1667 32.0833H26.25C25.4765 32.0833 24.7346 31.776 24.1876 31.2291C23.6406 30.6821 23.3333 29.9402 23.3333 29.1667V5.83334C23.3333 5.05979 23.6406 4.31792 24.1876 3.77094C24.7346 3.22396 25.4765 2.91667 26.25 2.91667H29.1667C29.5534 2.91667 29.9244 3.07032 30.1979 3.34381C30.4714 3.6173 30.625 3.98823 30.625 4.37501V30.625Z" stroke="#9A0000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';;
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
''';;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onToggle, // 🔒 disable when locked
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),

        width: size,
        height: size,

        decoration: BoxDecoration(
          color: isLocked
              ? Colors.grey.withOpacity(0.15)
              : isOn
                  ? Colors.green.withOpacity(0.25)
                  : Colors.grey.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: isLocked
                ? Colors.grey
                : isOn
                    ? Colors.green
                    : Colors.grey,
            width: 3,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // SVG Icon
            Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: SvgPicture.string(
                _getSvgIcon(label),
                width: label == 'Y' ? 30 : 28,
                height: label == 'Y' ? 30 : 28,
              ),
            ),

            // 🔒 Lock overlay
            if (isLocked)
              const Icon(
                Icons.lock,
                size: 18,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
}