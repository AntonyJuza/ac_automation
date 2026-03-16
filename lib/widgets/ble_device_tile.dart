import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ac_automation/utils/constants.dart';

class BLEDeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onConnect;

  const BLEDeviceTile({
    super.key,
    required this.result,
    required this.onConnect,
  });

  String get _deviceName {
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    return 'Unknown Device';
  }

  String get _deviceId => result.device.remoteId.toString();

  int get _rssi => result.rssi;

  IconData get _signalIcon {
    if (_rssi >= -60) return Icons.signal_wifi_4_bar;
    if (_rssi >= -75) return Icons.network_wifi_3_bar;
    if (_rssi >= -85) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Color get _signalColor {
    if (_rssi >= -60) return AppColors.statusGreen;
    if (_rssi >= -75) return const Color(0xFFF59E0B);
    return AppColors.statusRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppStyles.softShadow],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryBrand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.memory, color: AppColors.primaryBrand),
        ),
        title: Text(
          _deviceName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(_signalIcon, size: 14, color: _signalColor),
            const SizedBox(width: 4),
            Text(
              '$_rssi dBm  •  ${_deviceId.substring(0, 8)}...',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrand,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Connect',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }
}