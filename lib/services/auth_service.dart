import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ac_automation/utils/constants.dart';

class AuthService with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthService() {
    tryAutoLogin();
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('jwt_token')) {
        return false;
      }
      _token = prefs.getString('jwt_token');
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        _currentUser = json.decode(userDataStr) as Map<String, dynamic>;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error trying auto login: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('${APIConstants.baseUrl}/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print("LOGIN STATUS: ${response.statusCode}");
      print("LOGIN RESPONSE: ${response.body}");

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _token = data['token'];
        _currentUser = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setString('user_data', json.encode(_currentUser));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(data['error'] ?? 'Login failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('${APIConstants.baseUrl}/auth/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      print("REGISTER STATUS: ${response.statusCode}");
      print("REGISTER RESPONSE: ${response.body}");

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        _token = data['token'];
        _currentUser = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setString('user_data', json.encode(_currentUser));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(data['error'] ?? 'Registration failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    notifyListeners();
  }

  Future<bool> claimDevice(String deviceId) async {
    if (!isAuthenticated) return false;

    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices/claim');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({'deviceId': deviceId}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        // Update user's devices locally
        if (_currentUser != null) {
          final List<dynamic> devices = List.from(_currentUser!['devices'] ?? []);
          if (!devices.contains(deviceId)) {
            devices.add(deviceId);
            _currentUser!['devices'] = devices;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', json.encode(_currentUser));
          }
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error claiming device: $e');
      return false;
    }
  }
}
