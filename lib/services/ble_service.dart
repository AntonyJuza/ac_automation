import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/models/ir_button.dart';
import 'package:ac_automation/models/dynamic_config.dart';
import 'package:permission_handler/permission_handler.dart';

enum BLEState { idle, scanning, connecting, connected, error }

class BLECommands {
  static const String startLearn = 'LEARN_START';
  static const String stopLearn  = 'LEARN_STOP';
  static const String getStatus  = 'STATUS';
}

class BLEService extends ChangeNotifier {
  BLEState _state = BLEState.idle;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;

  final List<ScanResult> _scanResults = [];

  final _statusController  = StreamController<String>.broadcast();
  final _irButtonController = StreamController<IRButton>.broadcast();

  StreamSubscription? _statusSub;
  StreamSubscription? _irDataSub;
  StreamSubscription? _scanSub;

  // IR chunk reassembly — raw path
  final List<String> _irChunkBuffer = [];
  bool _irReceiving = false;

  // IR chunk reassembly — encoded path
  final StringBuffer _encBuffer = StringBuffer();
  bool _encReceiving = false;

  BLEState          get state           => _state;
  bool              get isConnected     => _state == BLEState.connected;
  bool              get isScanning      => _state == BLEState.scanning;
  BluetoothDevice?  get device          => _device;
  List<ScanResult>  get scanResults     => List.unmodifiable(_scanResults);
  Stream<String>    get statusStream    => _statusController.stream;
  Stream<IRButton>  get irButtonStream  => _irButtonController.stream;

  // ---------- Scan ----------

  Future<void> startScan() async {
    if (_state == BLEState.scanning) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    _scanResults.clear();
    _setState(BLEState.scanning);
    try {
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        bool changed = false;
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty 
              ? r.device.platformName 
              : r.advertisementData.advName;
          
          // Allow AC_Automation or empty name (sometimes name takes a moment to resolve)
          if (name.isNotEmpty && name != 'AC_Automation') continue;

          final idx = _scanResults
              .indexWhere((s) => s.device.remoteId == r.device.remoteId);
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
        timeout: const Duration(seconds: 10),
      );
      if (_state == BLEState.scanning) _setState(BLEState.idle);
    } catch (e) {
      debugPrint('[BLE] Scan error: $e');
      _setState(BLEState.error);
    }
  }

  Future<void> stopScan() async {
    debugPrint('[BLE] stopScan() called. Calling FlutterBluePlus.stopScan()');
    await FlutterBluePlus.stopScan();
    debugPrint('[BLE] FlutterBluePlus.stopScan() completed');
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
        if (state == BluetoothConnectionState.disconnected) _handleDisconnect();
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
    _cmdChar = null;
    _device  = null;
    _irChunkBuffer.clear();
    _irReceiving  = false;
    _encReceiving = false;
    _encBuffer.clear();
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
            _statusSub = char.onValueReceived.listen((value) {
              if (value.isEmpty) return;
              final msg = utf8.decode(value);
              debugPrint('[BLE] Status: $msg');
              _statusController.add(msg);
            });
            debugPrint('[BLE] Status characteristic subscribed');
          }

          if (uuid == BLEConstants.charIrDataUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _irDataSub = char.onValueReceived.listen(_handleIRFrame);
            debugPrint('[BLE] IR data characteristic subscribed');
          }
        }
        break;
      }
    }
    if (_cmdChar == null) {
      throw Exception('Command characteristic not found. Check ESP32 firmware UUIDs.');
    }
  }

  // ---------- IR Frame Handler ----------
  //
  // Two framing protocols on the IR data characteristic:
  //
  // ENCODED (PulseDistance — preferred):
  //   ENC_START → ENC:<json_chunk> × N → ENC_END
  //   Emits IRButton with method=encoded
  //
  // RAW (fallback for unknown protocols):
  //   IR_START:<count> → IR:<csv_chunk> × N → IR_END
  //   Emits IRButton with method=raw
  //
  void _handleIRFrame(List<int> value) {
    if (value.isEmpty) return;
    final msg = utf8.decode(value);
    debugPrint('[BLE] IR frame: ${msg.substring(0, msg.length.clamp(0, 70))}');

    // ── Encoded path ─────────────────────────────────────────────
    if (msg == 'ENC_START') {
      _encBuffer.clear();
      _encReceiving = true;
      debugPrint('[BLE] Encoded IR transfer started');
      return;
    }
    if (msg.startsWith('ENC:') && _encReceiving) {
      _encBuffer.write(msg.substring(4));
      return;
    }
    if (msg == 'ENC_END' && _encReceiving) {
      _encReceiving = false;
      final jsonStr = _encBuffer.toString();
      _encBuffer.clear();
      debugPrint('[BLE] Encoded JSON received: ${jsonStr.length} chars');
      _parseEncodedJson(jsonStr);
      return;
    }

    // ── Raw path ─────────────────────────────────────────────────
    if (msg.startsWith('IR_START:')) {
      _irChunkBuffer.clear();
      _irReceiving = true;
      debugPrint('[BLE] Raw IR transfer started');
      return;
    }
    if (msg.startsWith('IR:') && _irReceiving) {
      _irChunkBuffer.add(msg.substring(3));
      return;
    }
    if (msg == 'IR_END' && _irReceiving) {
      _irReceiving = false;
      final fullCsv = _irChunkBuffer.join(',');
      _irChunkBuffer.clear();
      final parsed = fullCsv
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .where((v) => v > 0)
          .toList();
      debugPrint('[BLE] Raw IR parsed: ${parsed.length} values');
      if (parsed.isNotEmpty) {
        _irButtonController.add(IRButton(name: '', method: IRMethod.raw, rawData: parsed));
      }
      return;
    }

    debugPrint('[BLE] IR unexpected frame: $msg');
  }

  void _parseEncodedJson(String jsonStr) {
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      final button = IRButton(
        name:      '',
        method:    IRMethod.encoded,
        hexData:   (map['data'] as List?)?.map((e) => e.toString()).toList(),
        bits:      map['bits'] as int?,
        hdrMark:   map['hdr_mark'] as int?,
        hdrSpace:  map['hdr_space'] as int?,
        bitMark:   map['bit_mark'] as int?,
        oneSpace:  map['one_space'] as int?,
        zeroSpace: map['zero_space'] as int?,
      );
      if (button.isValid) {
        debugPrint('[BLE] Encoded IR ready: ${button.bits} bits, ${button.hexData}');
        _irButtonController.add(button);
      } else {
        debugPrint('[BLE] Encoded IR invalid after parse');
      }
    } catch (e) {
      debugPrint('[BLE] Encoded JSON parse error: $e');
    }
  }

  // ---------- Write Commands ----------

  Future<bool> sendCommand(String command) async {
    if (_cmdChar == null || !isConnected) {
      debugPrint('[BLE] Cannot send — not connected');
      return false;
    }
    try {
      final bytes = utf8.encode(command);
      if (bytes.length <= 500) {
        await _cmdChar!.write(bytes, withoutResponse: false);
      } else {
        const chunkSize = 500;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          await _cmdChar!.write(bytes.sublist(i, end), withoutResponse: false);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      debugPrint('[BLE] Sent ${bytes.length} bytes: '
          '${command.substring(0, command.length.clamp(0, 60))}');
      return true;
    } catch (e) {
      debugPrint('[BLE] Write error: $e');
      return false;
    }
  }

  Future<bool> startLearnMode() => sendCommand(BLECommands.startLearn);
  Future<bool> stopLearnMode()  => sendCommand(BLECommands.stopLearn);

  /// Send an IR button command to the ESP32 to transmit
  Future<bool> transmitButton(String key, IRButton button) =>
      sendCommand(button.toSendCommand(key));

  /// Save a full profile to ESP32 NVS using chunked write protocol
  Future<bool> saveProfileToDevice(String profileJson) async {
    const int chunkSize = 450;

    final startOk = await sendCommand('PROFILE_START');
    if (!startOk) return false;

    try {
      await statusStream
          .firstWhere((s) => s == 'PROFILE_READY')
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[BLE] PROFILE_READY not received');
      return false;
    }

    int offset = 0;
    int chunkNum = 0;
    while (offset < profileJson.length) {
      final end = (offset + chunkSize < profileJson.length)
          ? offset + chunkSize
          : profileJson.length;
      final ok = await sendCommand('PROFILE_CHUNK:${profileJson.substring(offset, end)}');
      if (!ok) return false;
      offset = end;
      chunkNum++;
      await Future.delayed(const Duration(milliseconds: 30));
    }

    debugPrint('[BLE] Sent $chunkNum profile chunks');
    final endOk = await sendCommand('PROFILE_END');
    if (!endOk) return false;

    try {
      final response = await statusStream
          .firstWhere((s) => s.startsWith('PROFILE_SAVED:') || s.startsWith('ERR:'))
          .timeout(const Duration(seconds: 10));
      if (response.startsWith('ERR:')) {
        debugPrint('[BLE] Profile save error: $response');
        return false;
      }
      debugPrint('[BLE] Profile saved: $response');
      return true;
    } on TimeoutException {
      debugPrint('[BLE] PROFILE_SAVED confirmation timed out');
      return false;
    }
  }

  Future<bool> sendDynamicConfig(DynamicConfig config, {String name = "Dynamic_AC"}) async {
    final startOk = await sendCommand('VAR_START:$name');
    if (!startOk) return false;

    final payload = config.toPayload();
    for (final entry in payload.entries) {
      final ok = await sendCommand('VAR_CHUNK:${entry.key}:${entry.value}');
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 30));
    }

    final endOk = await sendCommand('VAR_END');
    if (!endOk) return false;

    try {
      final response = await statusStream
          .firstWhere((s) => s == 'VAR_SAVED' || s.startsWith('ERR:'))
          .timeout(const Duration(seconds: 10));
      if (response.startsWith('ERR:')) {
        debugPrint('[BLE] Dynamic config save error: $response');
        return false;
      }
      debugPrint('[BLE] Dynamic config saved: $response');
      return true;
    } on TimeoutException {
      debugPrint('[BLE] VAR_SAVED confirmation timed out');
      return false;
    }
  }

  Future<bool> setActiveProfile(String profileId) =>
      sendCommand('SET_ACTIVE:$profileId');

  Future<bool> deleteProfileOnDevice(String profileId) =>
      sendCommand('DELETE:$profileId');

  // ---------- Capture one IR button ----------

  Future<IRButton?> captureIRButton({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ok = await startLearnMode();
    if (!ok) return null;
    try {
      final button = await irButtonStream.first.timeout(timeout);
      await stopLearnMode();
      debugPrint('[BLE] Capture success: ${button.isEncoded ? "encoded ${button.bits}bits" : "raw ${button.rawData?.length} values"}');
      return button;
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
    _irButtonController.close();
    super.dispose();
  }
}