import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBackground = Color(0xFFFFFFFF);
  static const Color secondaryBackground = Color(0xFFF4F7FA);
  static const Color primaryBrand = Color(0xFF0A66C2);
  static const Color secondaryAccent = Color(0xFF00B4D8);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color statusGreen = Color(0xFF10B981);
}

class AppStyles {
  static const double borderRadius = 16.0;
  static final BoxShadow softShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );
}
class BLEConstants {
  static const String serviceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String charCommandUuid = "12345678-1234-1234-1234-123456789001";
  static const String charStatusUuid = "12345678-1234-1234-1234-123456789002";
  static const String charIrDataUuid = "12345678-1234-1234-1234-123456789003";
}
