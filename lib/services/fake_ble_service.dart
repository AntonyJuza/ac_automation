import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ac_automation/models/ir_button.dart';
import 'package:ac_automation/models/dynamic_config.dart';
import 'ble_service.dart';

/// Drop-in mock for [BLEService]. No real hardware or Bluetooth needed.
/// Enable via [kUseFakeBLE] = true in main.dart.
class FakeBLEService extends BLEService {
  BLEState _fakeState = BLEState.idle;
  bool _fakeConnected = false;

  final _fakeStatusCtrl = StreamController<String>.broadcast();
  final _fakeIrCtrl = StreamController<IRButton>.broadcast();

  final List<ScanResult> _fakeScanResults = [];

  @override
  BLEState get state => _fakeState;

  @override
  bool get isConnected => _fakeConnected;

  @override
  bool get isScanning => _fakeState == BLEState.scanning;

  @override
  List<ScanResult> get scanResults => List.unmodifiable(_fakeScanResults);

  static ScanResult _makeFakeResult(String name, String macSuffix) {
    return ScanResult(
      device: BluetoothDevice(remoteId: DeviceIdentifier('AA:BB:CC:DD:EE:$macSuffix')),
      advertisementData: AdvertisementData(
        advName: name,
        txPowerLevel: null,
        appearance: null,
        connectable: true,
        manufacturerData: {},
        serviceData: {},
        serviceUuids: [],
      ),
      rssi: -65,
      timeStamp: DateTime.now(),
    );
  }

  @override
  Stream<String> get statusStream => _fakeStatusCtrl.stream;

  @override
  Stream<IRButton> get irButtonStream => _fakeIrCtrl.stream;

  // ── Scan ──────────────────────────────────────────────────────────────────

  @override
  Future<void> startScan() async {
    if (_fakeState == BLEState.scanning) return;
    _fakeScanResults.clear();
    _setFakeState(BLEState.scanning);
    debugPrint('[FakeBLE] Scanning...');

    await Future.delayed(const Duration(seconds: 2));
    _fakeScanResults.addAll([
      _makeFakeResult('AC_Automation_01', '01'),
      _makeFakeResult('AC_Automation_02', '02'),
    ]);
    debugPrint('[FakeBLE] Found ${_fakeScanResults.length} fake devices');
    _setFakeState(BLEState.idle);
  }

  @override
  Future<void> stopScan() async {
    if (_fakeState == BLEState.scanning) _setFakeState(BLEState.idle);
  }

  // ── Connect ───────────────────────────────────────────────────────────────

  /// Call this to simulate connecting to a named fake device.
  Future<void> connectFake(String name) async {
    _setFakeState(BLEState.connecting);
    debugPrint('[FakeBLE] Connecting to $name...');
    await Future.delayed(const Duration(seconds: 1));
    _fakeConnected = true;
    _setFakeState(BLEState.connected);
    debugPrint('[FakeBLE] Connected to $name');

    // Simulate initial status push from device
    Future.delayed(const Duration(milliseconds: 500), () {
      _fakeStatusCtrl.add(
        'AC=OFF|PRESENCE=NO|CONFIG=FakeAC|ON_TIME=60000|OFF_TIME=300000',
      );
    });
  }

  /// connectTo is called with a real BluetoothDevice — redirect to connectFake.
  @override
  Future<void> connectTo(BluetoothDevice device) {
    // Find the matching fake result to get the advertised name
    final match = _fakeScanResults.firstWhere(
      (r) => r.device.remoteId == device.remoteId,
      orElse: () => _fakeScanResults.first,
    );
    final name = match.advertisementData.advName.isNotEmpty
        ? match.advertisementData.advName
        : 'FakeDevice';
    return connectFake(name);
  }

  @override
  Future<void> disconnect() async {
    _fakeConnected = false;
    _setFakeState(BLEState.idle);
    debugPrint('[FakeBLE] Disconnected');
  }

  // ── Commands ──────────────────────────────────────────────────────────────

  @override
  Future<bool> sendCommand(String command) async {
    if (!isConnected) return false;
    debugPrint('[FakeBLE] → $command');
    await Future.delayed(const Duration(milliseconds: 80));

    if (command == 'STATUS') {
      _fakeStatusCtrl.add('AC=ON|PRESENCE=YES|CONFIG=FakeAC|ON_TIME=60000|OFF_TIME=300000');
    } else if (command.startsWith('SET_TIMING:')) {
      _fakeStatusCtrl.add('TIMING_OK');
    } else if (command == 'PROFILE_START') {
      Future.delayed(const Duration(milliseconds: 200),
          () => _fakeStatusCtrl.add('PROFILE_READY'));
    } else if (command == 'PROFILE_END') {
      Future.delayed(const Duration(milliseconds: 300),
          () => _fakeStatusCtrl.add('PROFILE_SAVED:FakeAC'));
    } else if (command == 'VAR_END') {
      Future.delayed(const Duration(milliseconds: 300),
          () => _fakeStatusCtrl.add('VAR_SAVED'));
    }
    return true;
  }

  @override
  Future<bool> startLearnMode() => sendCommand('LEARN_START');

  @override
  Future<bool> stopLearnMode() => sendCommand('LEARN_STOP');

  @override
  Future<bool> transmitButton(String key, IRButton button) =>
      sendCommand(button.toSendCommand(key));

  @override
  Future<bool> setTiming(int onMs, int offMs) =>
      sendCommand('SET_TIMING:$onMs:$offMs');

  @override
  Future<bool> getTiming() => sendCommand('GET_TIMING');

  @override
  Future<bool> setActiveProfile(String profileId) =>
      sendCommand('SET_ACTIVE:$profileId');

  @override
  Future<bool> deleteProfileOnDevice(String profileId) =>
      sendCommand('DELETE:$profileId');

  @override
  Future<bool> clearDeviceConfig() => sendCommand('CLEAR_CONFIG');

  @override
  Future<bool> saveProfileToDevice(String profileJson) async {
    await sendCommand('PROFILE_START');
    await Future.delayed(const Duration(milliseconds: 400));
    await sendCommand('PROFILE_END');
    return true;
  }

  @override
  Future<bool> sendDynamicConfig(DynamicConfig config,
      {String name = 'Dynamic_AC'}) async {
    await sendCommand('VAR_START:$name');
    await sendCommand('VAR_END');
    return true;
  }

  // ── Fake IR Capture ───────────────────────────────────────────────────────

  @override
  Future<IRButton?> captureIRButton({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await startLearnMode();
    debugPrint('[FakeBLE] Waiting for fake IR signal...');
    await Future.delayed(const Duration(seconds: 2));

    final fakeButton = IRButton(
      name: '',
      method: IRMethod.encoded,
      hexData: ['0x1FE50AF'],
      bits: 32,
      hdrMark: 9000,
      hdrSpace: 4500,
      bitMark: 560,
      oneSpace: 1690,
      zeroSpace: 560,
    );
    _fakeIrCtrl.add(fakeButton);
    await stopLearnMode();
    debugPrint('[FakeBLE] Fake IR captured');
    return fakeButton;
  }

  void _setFakeState(BLEState s) {
    _fakeState = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _fakeStatusCtrl.close();
    _fakeIrCtrl.close();
    super.dispose();
  }
}
