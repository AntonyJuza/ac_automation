import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ac_automation/services/api_service.dart';

class ACProvider with ChangeNotifier {
  List<ACProfile> _profiles = [];
  bool _isPresenceDetected = false;
  String _presenceStatus = 'NONE';
  bool _isAcOn = false;
  bool _isConnected = false;
  String _configName = '';
  int _onTimeMs = 60000;
  int _offTimeMs = 300000;
  String _deviceId = 'UNKNOWN';
  bool _isWifiConnected = false;

  List<Map<String, dynamic>> _cloudDevices = [];
  bool _isFetchingDevices = false;
  Map<String, dynamic>? _selectedDevice;

  List<ACProfile> get profiles => _profiles;
  bool get isPresenceDetected => _isPresenceDetected;
  String get presenceStatus => _presenceStatus;
  bool get isAcOn => _isAcOn;
  bool get isConnected => _isConnected;
  String get configName => _configName;
  int get onTimeMs => _onTimeMs;
  int get offTimeMs => _offTimeMs;
  String get deviceId => _deviceId;
  bool get isWifiConnected => _isWifiConnected;

  List<Map<String, dynamic>> get cloudDevices => _cloudDevices;
  bool get isFetchingDevices => _isFetchingDevices;
  Map<String, dynamic>? get selectedDevice => _selectedDevice;

  ACProvider() {
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesRaw = prefs.getStringList('ac_profiles') ?? [];
    _profiles = profilesRaw
        .map((p) => ACProfile.fromJson(json.decode(p)))
        .toList();
    notifyListeners();
  }

  Future<void> addProfile(ACProfile profile) async {
    _profiles.add(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ac_profiles',
      _profiles.map((p) => json.encode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ac_profiles',
      _profiles.map((p) => json.encode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  void setPresence(bool detected) {
    _isPresenceDetected = detected;
    notifyListeners();
  }

  void setConnectionStatus(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  String? _lastError;
  String? get lastError => _lastError;

  void updateFromStatus(String status) {
    if (status.startsWith('ERR:')) {
      _lastError = status.substring(4);
      notifyListeners();
      return;
    }

    if (status.startsWith('WS:')) {
      final stat = status.substring(3);
      final wifiConn = (stat == 'con' || stat == 'CONNECTED');
      if (_isWifiConnected != wifiConn) {
        _isWifiConnected = wifiConn;
        notifyListeners();
      }
      return;
    }
    
    _lastError = null;
    // Expected format: AC=OFF|PRESENCE=YES
    final parts = status.split('|');
    for (var part in parts) {
      if (part.startsWith('PRESENCE=')) {
        final statusVal = part.split('=')[1];
        if (_presenceStatus != statusVal) {
          _presenceStatus = statusVal;
          _isPresenceDetected = (statusVal == 'YES' || statusVal == 'MOVING' || statusVal == 'STATIC' || statusVal == 'BOTH');
        }
      }
      if (part.startsWith('AC=')) {
        final isOn = part.split('=')[1] == 'ON';
        if (_isAcOn != isOn) _isAcOn = isOn;
      }
      if (part.startsWith('CONFIG=')) {
        final name = part.split('=')[1];
        if (name != 'NONE' && _configName != name) _configName = name;
      }
      if (part.startsWith('ON_TIME=')) {
        _onTimeMs = int.tryParse(part.split('=')[1]) ?? _onTimeMs;
      }
      if (part.startsWith('OFF_TIME=')) {
        _offTimeMs = int.tryParse(part.split('=')[1]) ?? _offTimeMs;
      }
      if (part.startsWith('ID=')) {
        final id = part.split('=')[1];
        if (_deviceId != id) {
          _deviceId = id;
          _syncWithCloud();
          // Auto claim when device ID is discovered in BLE setup
          claimCloudDevice(id);
        }
      }
      if (part.startsWith('WIFI=')) {
        final wifiStat = part.split('=')[1];
        final wifiConn = (wifiStat == 'con' || wifiStat == 'CONNECTED');
        if (_isWifiConnected != wifiConn) {
          _isWifiConnected = wifiConn;
        }
      }
    }
    notifyListeners();
  }

  Future<void> _syncWithCloud() async {
    if (_deviceId == 'UNKNOWN') return;
    
    debugPrint('[Scanner] Fetching cloud data for $_deviceId');
    final data = await ApiService.getDevice(_deviceId);
    if (data != null && data['configData'] != null) {
       final profileMap = data['configData'];
       try {
         final profile = ACProfile.fromJson(profileMap);
         bool exists = _profiles.any((p) => p.id == profile.id || p.name == profile.name);
         if (!exists) {
           await addProfile(profile);
           debugPrint('[App] Seamlessly downloaded profile ${profile.name} from Cloud!');
         }
       } catch(e) {
         debugPrint('[App] Error parsing cloud profile: $e');
       }
    }
  }

  void selectDevice(Map<String, dynamic>? device) {
    _selectedDevice = device;
    if (device != null) {
      _deviceId = device['deviceId'] ?? 'UNKNOWN';
      _isAcOn = device['powerState'] ?? false;
      _isWifiConnected = device['online'] ?? false;
      _configName = device['activeConfigName'] ?? 'NONE';
      
      if (device['configData'] != null) {
         try {
           final profileMap = device['configData'];
           final profile = ACProfile.fromJson(profileMap);
           bool exists = _profiles.any((p) => p.id == profile.id || p.name == profile.name);
           if (!exists) {
             addProfile(profile);
           }
         } catch(e) {
           debugPrint('[App] Error parsing configData from cloud: $e');
         }
      }
    } else {
      _deviceId = 'UNKNOWN';
      _isAcOn = false;
      _isWifiConnected = false;
      _configName = 'NONE';
    }
    notifyListeners();
  }

  Future<void> fetchCloudDevices() async {
    if (_isFetchingDevices) return;
    _isFetchingDevices = true;
    notifyListeners();

    try {
      final devices = await ApiService.getUserDevices();
      if (devices != null) {
        _cloudDevices = devices;
        
        if (_selectedDevice != null) {
          final updated = _cloudDevices.firstWhere(
            (d) => d['deviceId'] == _selectedDevice!['deviceId'],
            orElse: () => <String, dynamic>{},
          );
          if (updated.isNotEmpty) {
            selectDevice(updated);
          } else {
            selectDevice(_cloudDevices.isNotEmpty ? _cloudDevices.first : null);
          }
        } else if (_cloudDevices.isNotEmpty) {
          selectDevice(_cloudDevices.first);
        } else {
          selectDevice(null);
        }

        await _fetchLatestPresenceForSelectedDevice();
      }
    } catch (e) {
      debugPrint('Error fetching cloud devices: $e');
    } finally {
      _isFetchingDevices = false;
      notifyListeners();
    }
  }

  Future<void> _fetchLatestPresenceForSelectedDevice() async {
    if (_selectedDevice == null) return;
    final devId = _selectedDevice!['deviceId'];
    try {
      final events = await ApiService.getEvents();
      if (events != null && events.isNotEmpty) {
        final devEvent = events.firstWhere(
          (e) => e['device_id'] == devId,
          orElse: () => <String, dynamic>{},
        );
        if (devEvent.isNotEmpty) {
          final presenceVal = devEvent['presence'];
          final eventName = devEvent['event'] ?? '';
          
          if (presenceVal == true || presenceVal == 1) {
            _isPresenceDetected = true;
            _presenceStatus = 'YES';
          } else {
            _isPresenceDetected = false;
            _presenceStatus = 'NONE';
          }
          
          if (eventName == 'AC_ON') {
            _isAcOn = true;
          } else if (eventName == 'AC_OFF') {
            _isAcOn = false;
          }
        }
      }
    } catch(e) {
      debugPrint('Error fetching latest presence: $e');
    }
  }

  Future<bool> claimCloudDevice(String deviceId) async {
    final success = await ApiService.claimDevice(deviceId);
    if (success) {
      await fetchCloudDevices();
      final claimed = _cloudDevices.firstWhere(
        (d) => d['deviceId'] == deviceId,
        orElse: () => <String, dynamic>{},
      );
      if (claimed.isNotEmpty) {
        selectDevice(claimed);
      }
      return true;
    }
    return false;
  }

  Future<bool> controlCloudDevicePower(bool turnOn) async {
    if (_selectedDevice == null) return false;
    final devId = _selectedDevice!['deviceId'];
    
    _isAcOn = turnOn;
    notifyListeners();

    final success = await ApiService.toggleDevicePower(devId, turnOn);
    if (success) {
      await fetchCloudDevices();
      return true;
    } else {
      _isAcOn = !turnOn;
      notifyListeners();
      return false;
    }
  }
}
