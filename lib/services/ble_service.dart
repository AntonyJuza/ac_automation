import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE connection states for the UI to react to
enum BLEState {
  idle,       // Not scanning, not connected
  scanning,   // Actively scanning for devices
  connecting, // Found device, attempting to connect
  connected,  // Connected and characteristics discovered
  error,      // Something went wrong
}

/// Commands sent to ESP32 via the command characteristic
class BLECommands {
  static const String startLearn  = 'LEARN_START';
  static const String stopLearn   = 'LEARN_STOP';
  static const String getStatus   = 'STATUS';
  // IR transmit: SEND:<button_key>:<raw_data_csv>
  static String sendIR(String key, List<int> rawData) =>
      'SEND:$key:${rawData.join(',')}';
}

class BLEService extends ChangeNotifier {
  // ---------- State ----------
  BLEState _state = BLEState.idle;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;    // Write

  // Scanned devices list (shown in scan UI)
  final List<ScanResult> _scanResults = [];

  // Stream controllers so screens can listen to incoming data
  final _statusController  = StreamController<String>.broadcast();
  final _irDataController  = StreamController<List<int>>.broadcast();

  // Subscriptions to clean up on disconnect
  StreamSubscription? _statusSub;
  StreamSubscription? _irDataSub;
  StreamSubscription? _scanSub;

  // ---------- Getters ----------
  BLEState           get state        => _state;
  bool               get isConnected  => _state == BLEState.connected;
  bool               get isScanning   => _state == BLEState.scanning;
  BluetoothDevice?   get device       => _device;
  List<ScanResult>   get scanResults  => List.unmodifiable(_scanResults);
  Stream<String>     get statusStream => _statusController.stream;
  Stream<List<int>>  get irDataStream => _irDataController.stream;

  // ---------- Scan ----------

  /// Start BLE scan. Handles runtime permissions and filters (disabled for testing).
  Future<void> startScan() async {
    if (_state == BLEState.scanning) return;

    // Request permissions for Android 12+ (Bluetooth) and Android 11- (Location)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isDenied == true ||
        statuses[Permission.location]?.isDenied == true) {
      debugPrint('[BLE] Missing required permissions');
      // Ideally we would show a UI error here.
    }

    // Check if Bluetooth is ON
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      debugPrint('[BLE] Bluetooth is off');
      // Ideally we would prompt user to turn on Bluetooth here.
    }

    _scanResults.clear();
    _setState(BLEState.scanning);

    try {
      await _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        bool changed = false;
        for (final r in results) {
          final idx = _scanResults.indexWhere(
              (s) => s.device.remoteId == r.device.remoteId);
          if (idx >= 0) {
            _scanResults[idx] = r;
          } else {
            _scanResults.add(r);
            changed = true;
          }
        }
        if (changed) notifyListeners();
      });

      await FlutterBluePlus.startScan(
        // Temporarily commented out to see ALL nearby devices for testing
        // withServices: [Guid(BLEConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );

      if (_state == BLEState.scanning) _setState(BLEState.idle);

    } catch (e) {
      debugPrint('[BLE] Scan error: $e');
      _setState(BLEState.error);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (_state == BLEState.scanning) _setState(BLEState.idle);
  }

  // ---------- Connect ----------

  Future<void> connectTo(BluetoothDevice device) async {
    await stopScan();
    _setState(BLEState.connecting);

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverServices(device);
      _setState(BLEState.connected);

    } catch (e) {
      debugPrint('[BLE] Connect error: $e');
      _setState(BLEState.error);
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _statusSub?.cancel();
    _irDataSub?.cancel();
    _cmdChar    = null;
    _device     = null;
    _setState(BLEState.idle);
  }

  // ---------- Service & Characteristic Discovery ----------

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.serviceUuid == Guid(BLEConstants.serviceUuid)) {
        for (final char in service.characteristics) {
          final uuid = char.characteristicUuid.toString().toLowerCase();

          if (uuid == BLEConstants.charCommandUuid.toLowerCase()) {
            _cmdChar = char;
            debugPrint('[BLE] Command characteristic found');
          }

          if (uuid == BLEConstants.charStatusUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _statusSub = char.lastValueStream.listen((value) {
              final msg = utf8.decode(value);
              debugPrint('[BLE] Status: $msg');
              _statusController.add(msg);
            });
            debugPrint('[BLE] Status characteristic subscribed');
          }

          if (uuid == BLEConstants.charIrDataUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _irDataSub = char.lastValueStream.listen((value) {
              debugPrint('[BLE] IR data: ${value.length} bytes');
              _irDataController.add(value);
            });
            debugPrint('[BLE] IR data characteristic subscribed');
          }
        }
        break;
      }
    }

    if (_cmdChar == null) {
      throw Exception(
          'Command characteristic not found. Check ESP32 firmware UUIDs.');
    }
  }

  // ---------- Write Commands ----------

  /// Write a string command to the ESP32 command characteristic
  Future<bool> sendCommand(String command) async {
    if (_cmdChar == null || !isConnected) {
      debugPrint('[BLE] Cannot send — not connected');
      return false;
    }
    try {
      await _cmdChar!.write(utf8.encode(command), withoutResponse: false);
      debugPrint('[BLE] Sent: $command');
      return true;
    } catch (e) {
      debugPrint('[BLE] Write error: $e');
      return false;
    }
  }

  Future<bool> startLearnMode() => sendCommand(BLECommands.startLearn);
  Future<bool> stopLearnMode()  => sendCommand(BLECommands.stopLearn);

  Future<bool> transmitIR(String buttonKey, List<int> rawData) =>
      sendCommand(BLECommands.sendIR(buttonKey, rawData));

  // ---------- Capture one IR button ----------

  /// Puts ESP32 into learn mode and waits for it to send back captured raw IR.
  /// Returns raw pulse list, or null on timeout/error.
  Future<List<int>?> captureIRButton({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final ok = await startLearnMode();
    if (!ok) return null;

    try {
      final data = await irDataStream.first.timeout(timeout);
      await stopLearnMode();
      return data;
    } on TimeoutException {
      debugPrint('[BLE] Capture timed out');
      await stopLearnMode();
      return null;
    } catch (e) {
      debugPrint('[BLE] Capture error: $e');
      await stopLearnMode();
      return null;
    }
  }

  // ---------- Helpers ----------

  void _setState(BLEState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _irDataSub?.cancel();
    _scanSub?.cancel();
    _statusController.close();
    _irDataController.close();
    super.dispose();
  }
}