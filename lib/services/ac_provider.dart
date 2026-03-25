import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ACProvider with ChangeNotifier {
  List<ACProfile> _profiles = [];
  bool _isPresenceDetected = false;
  String _presenceStatus = 'NONE';
  bool _isAcOn = false;
  bool _isConnected = false;
  String _configName = '';
  int _onTimeMs = 60000;
  int _offTimeMs = 300000;

  List<ACProfile> get profiles => _profiles;
  bool get isPresenceDetected => _isPresenceDetected;
  String get presenceStatus => _presenceStatus;
  bool get isAcOn => _isAcOn;
  bool get isConnected => _isConnected;
  String get configName => _configName;
  int get onTimeMs => _onTimeMs;
  int get offTimeMs => _offTimeMs;

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
    }
    notifyListeners();
  }
}
