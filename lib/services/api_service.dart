import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ac_automation/utils/constants.dart';

class ApiService {
  static void Function()? onUnauthorized;

  static void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint(
        '[ApiService] Unauthorized (401) response received, triggering onUnauthorized callback',
      );
      onUnauthorized?.call();
    }
  }

  static Future<bool> syncDevice({
    required String deviceId,
    String? deviceName,
    String? activeConfigName,
    Map<String, dynamic>? configData,
    int? defaultTurnOnTemp,
  }) async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices/sync');
      final body = {
        'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
        if (activeConfigName != null) 'activeConfigName': activeConfigName,
        if (configData != null) 'configData': configData,
        if (defaultTurnOnTemp != null) 'defaultTurnOnTemp': defaultTurnOnTemp,
      };

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      debugPrint('Syncing device to cloud: $deviceId');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('[Cloud] Response: ${response.statusCode} - ${response.body}');
      _checkResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[Cloud] Sync successful!');
        return true;
      } else {
        debugPrint('[Cloud] Sync failed: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[Cloud] Sync Error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices/$deviceId');
      debugPrint('Fetching device data from cloud: $url');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        debugPrint('Cloud fetch successful!');
        return jsonDecode(response.body);
      }
      debugPrint('Cloud fetch failed: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Get Device Error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getUserDevices() async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices');
      debugPrint('Fetching user devices: $url');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> list = decoded['data'] ?? [];
          return list.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      debugPrint(
        'Get User Devices failed: HTTP ${response.statusCode} - ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Get User Devices Error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getEvents() async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/events');
      debugPrint('Fetching events: $url');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true) {
            final List<dynamic> list = decoded['data'] ?? [];
            return list.map((item) => item as Map<String, dynamic>).toList();
          }
        } else if (decoded is List) {
          return decoded.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      debugPrint('Get Events failed: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Get Events Error: $e');
      return null;
    }
  }

  static Future<bool> claimDevice(String deviceId) async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices/claim');
      debugPrint('Claiming device: $url | ID: $deviceId');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'deviceId': deviceId}),
      );

      _checkResponse(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      debugPrint('Claim device failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Claim Device Error: $e');
      return false;
    }
  }

  static Future<bool> toggleDevicePower(String deviceId, bool turnOn) async {
    try {
      final endpoint = turnOn ? 'power-on' : 'power-off';
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/$endpoint',
      );
      debugPrint('Toggling power ($turnOn) via URL: $url');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      debugPrint('Toggle power failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Toggle Power Error: $e');
      return false;
    }
  }

  static Future<bool> startLearn(String deviceId) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/learn-start',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      _checkResponse(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Start Learn Error: $e');
      return false;
    }
  }

  static Future<bool> stopLearn(String deviceId) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/learn-stop',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      _checkResponse(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Stop Learn Error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCapturedIr(String deviceId) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/captured-ir',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      _checkResponse(response);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get Captured IR Error: $e');
      return null;
    }
  }

  static Future<bool> setTiming({
    required String deviceId,
    required int onTime,
    required int offTime,
  }) async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices/$deviceId/timing');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'onTime': onTime, 'offTime': offTime}),
      );
      _checkResponse(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Set Timing Error: $e');
      return false;
    }
  }

  static Future<bool> setTimeConfig({
    required String deviceId,
    required int gmtOffset,
    required int dstOffset,
  }) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/time-config',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'gmtOffset': gmtOffset, 'dstOffset': dstOffset}),
      );
      _checkResponse(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Set Time Config Error: $e');
      return false;
    }
  }

  static Future<bool> setRadarBypass({
    required String deviceId,
    required bool bypass,
  }) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/radar-bypass',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'bypass': bypass}),
      );
      _checkResponse(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Set Radar Bypass Error: $e');
      return false;
    }
  }

  static Future<bool> changeTemperature({
    required String deviceId,
    required int temp,
  }) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/devices/$deviceId/temperature',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'temp': temp}),
      );
      _checkResponse(response);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Change Temperature Error: $e');
      return false;
    }
  }
}
