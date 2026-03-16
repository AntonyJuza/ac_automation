import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ACProvider with ChangeNotifier {
  List<ACProfile> _profiles = [];
  bool _isPresenceDetected = false;
  bool _isConnected = false;

  List<ACProfile> get profiles => _profiles;
  bool get isPresenceDetected => _isPresenceDetected;
  bool get isConnected => _isConnected;

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
}
