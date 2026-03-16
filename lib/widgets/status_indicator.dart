import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ble_service.dart';

class StatusIndicator extends StatelessWidget {
  final BLEState state;
  final String? deviceName;

  const StatusIndicator({
    super.key,
    required this.state,
    this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dot
          _buildDot(),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: _bgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    if (state == BLEState.scanning || state == BLEState.connecting) {
      return SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _bgColor,
        ),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _bgColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Color get _bgColor {
    switch (state) {
      case BLEState.connected:   return AppColors.statusGreen;
      case BLEState.scanning:    return AppColors.primaryBrand;
      case BLEState.connecting:  return const Color(0xFFF59E0B);
      case BLEState.error:       return AppColors.statusRed;
      case BLEState.idle:        return AppColors.textSecondary;
    }
  }

  String get _label {
    switch (state) {
      case BLEState.connected:   return deviceName ?? 'Connected';
      case BLEState.scanning:    return 'Scanning...';
      case BLEState.connecting:  return 'Connecting...';
      case BLEState.error:       return 'Error';
      case BLEState.idle:        return 'Not Connected';
    }
  }
}