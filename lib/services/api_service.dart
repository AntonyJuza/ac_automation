import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ac_automation/utils/constants.dart';

class ApiService {
  static Future<bool> syncDevice({
    required String deviceId,
    String? deviceName,
    String? activeConfigName,
    Map<String, dynamic>? configData,
  }) async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/devices/sync');
      final body = {
        'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
        if (activeConfigName != null) 'activeConfigName': activeConfigName,
        if (configData != null) 'configData': configData,
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
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
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
}

