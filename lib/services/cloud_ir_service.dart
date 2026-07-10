import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/models/ir_button.dart';

/// Represents one cloud IR profile (a full set of button patterns for an AC).
class CloudIRProfile {
  final String id;
  final String brand;
  final String? model;
  final int profileIndex; // maps to profileId from server
  final Map<String, IRButton> buttons;

  CloudIRProfile({
    required this.id,
    required this.brand,
    this.model,
    required this.profileIndex,
    required this.buttons,
  });

  factory CloudIRProfile.fromJson(Map<String, dynamic> json) {
    final buttonsMap = <String, IRButton>{};
    if (json['buttons'] != null && json['buttons'] is Map) {
      (json['buttons'] as Map<String, dynamic>).forEach((key, value) {
        buttonsMap[key] = IRButton.fromJson(value as Map<String, dynamic>);
      });
    }
    return CloudIRProfile(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      brand: json['brand'] ?? '',
      model: json['model'],
      profileIndex: json['profileId'] ?? json['profileIndex'] ?? 1,
      buttons: buttonsMap,
    );
  }
}

/// Service for fetching pre-recorded IR profiles from the cloud database.
class CloudIRService {
  /// Fetch list of available AC brands that have cloud profiles.
  static Future<List<String>> fetchBrands() async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/profiles/brands');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['brands'] is List) {
          return List<String>.from(decoded['brands']);
        }
      }
      debugPrint('[CloudIR] Fetch brands failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[CloudIR] Fetch brands error: $e');
      return [];
    }
  }

  /// Fetch all cloud IR profiles for a specific brand (without full buttons payload).
  static Future<List<CloudIRProfile>> fetchProfilesForBrand(
    String brand,
  ) async {
    try {
      final url = Uri.parse(
        '${APIConstants.baseUrl}/profiles/brand/${Uri.encodeComponent(brand)}',
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['profiles'] is List) {
          final list = decoded['profiles'] as List;
          return list
              .map(
                (item) =>
                    CloudIRProfile.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
      debugPrint(
        '[CloudIR] Fetch profiles for $brand failed: ${response.statusCode}',
      );
      return [];
    } catch (e) {
      debugPrint('[CloudIR] Fetch profiles error: $e');
      return [];
    }
  }

  /// Fetch details of a specific profile (with button patterns) by ID.
  static Future<CloudIRProfile?> fetchProfileDetails(String id) async {
    try {
      final url = Uri.parse('${APIConstants.baseUrl}/profiles/$id');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        url,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['profile'] != null) {
          return CloudIRProfile.fromJson(
            decoded['profile'] as Map<String, dynamic>,
          );
        }
      }
      debugPrint('[CloudIR] Fetch profile details failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[CloudIR] Fetch profile details error: $e');
      return null;
    }
  }
}
