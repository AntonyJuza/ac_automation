import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/widgets/ble_device_tile.dart';
import 'package:ac_automation/models/ac_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  Timer? _pollTimer;

  // Timing controls (in minutes for UI, sent as ms)
  double _onDelayMin = 1.0;
  double _offDelayMin = 5.0;

  int _lastProviderOnTime = -1;
  int _lastProviderOffTime = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final acProvider = Provider.of<ACProvider>(context, listen: false);
      
      bleService.statusStream.listen((msg) {
        if (mounted) acProvider.updateFromStatus(msg);
      });

      // Initial cloud devices fetch
      acProvider.fetchCloudDevices();

      // Poll cloud devices status every 8 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted && acProvider.cloudDevices.isNotEmpty) {
          acProvider.fetchCloudDevices();
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);
    final acProvider = Provider.of<ACProvider>(context);
    final profile = acProvider.profiles.isNotEmpty ? acProvider.profiles.first : null;

    // Sync sliders with device timing if the underlying value changes
    if (acProvider.onTimeMs != _lastProviderOnTime) {
      _lastProviderOnTime = acProvider.onTimeMs;
      _onDelayMin = (_lastProviderOnTime / 60000.0).clamp(0.5, 30.0);
    }
    if (acProvider.offTimeMs != _lastProviderOffTime) {
      _lastProviderOffTime = acProvider.offTimeMs;
      _offDelayMin = (_lastProviderOffTime / 60000.0).clamp(0.5, 30.0);
    }

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: _buildAppBar(bleService, acProvider),
      body: RefreshIndicator(
        onRefresh: () => acProvider.fetchCloudDevices(),
        color: AppColors.primaryBrand,
        child: acProvider.isFetchingDevices && acProvider.cloudDevices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : acProvider.cloudDevices.isEmpty
                ? _buildNoDevicesScreen(context, bleService, acProvider)
                : _buildDeviceDashboard(context, bleService, acProvider, profile),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── No Devices Screen ───────────────────────────────────────────────────

  Widget _buildNoDevicesScreen(BuildContext context, BLEService bleService, ACProvider acProvider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.qr_code_scanner_rounded,
          size: 90,
          color: AppColors.primaryBrand.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 24),
        const Text(
          'No AC Units Found',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Claim your AC controller via QR code, or set up a brand new device using Bluetooth.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: () => _showQRClaimDialog(context, acProvider),
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
          label: const Text(
            'Scan QR Code / Claim Device',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrand,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showScanSheet(context, bleService),
          icon: const Icon(Icons.bluetooth, color: AppColors.primaryBrand),
          label: const Text(
            'Provision New Device (BLE)',
            style: TextStyle(color: AppColors.primaryBrand, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ── Device Dashboard ────────────────────────────────────────────────────

  Widget _buildDeviceDashboard(BuildContext context, BLEService bleService, ACProvider acProvider, ACProfile? profile) {
    final device = acProvider.selectedDevice;
    final deviceName = device?['deviceName'] ?? 'Living Room AC';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeviceSelector(acProvider),
          const SizedBox(height: 12),
          _buildHeroSection(
            acProvider.configName.isNotEmpty 
                ? acProvider.configName 
                : (profile?.name ?? deviceName),
            acProvider,
          ),
          const SizedBox(height: 16),
          _buildPowerBanner(acProvider, bleService),
          const SizedBox(height: 16),
          _buildTimingSection(bleService, acProvider),
          const SizedBox(height: 24),
          _buildControlActionsRow(context, bleService, acProvider),
        ],
      ),
    );
  }

  // ── Device Selector ─────────────────────────────────────────────────────

  Widget _buildDeviceSelector(ACProvider acProvider) {
    if (acProvider.cloudDevices.length <= 1) {
      final deviceId = acProvider.selectedDevice?['deviceId'] ?? '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'Device ID: $deviceId',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppStyles.softShadow],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: acProvider.selectedDevice,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBrand),
          items: acProvider.cloudDevices.map((device) {
            final name = device['deviceName'] ?? 'Unnamed Device';
            final id = device['deviceId'] ?? '';
            final isOnline = device['online'] ?? false;
            return DropdownMenuItem<Map<String, dynamic>>(
              value: device,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.statusGreen : AppColors.statusRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$name ($id)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (device) {
            if (device != null) {
              acProvider.selectDevice(device);
            }
          },
        ),
      ),
    );
  }

  // ── Control Actions Row ─────────────────────────────────────────────────

  Widget _buildControlActionsRow(BuildContext context, BLEService bleService, ACProvider acProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          onPressed: () => _showQRClaimDialog(context, acProvider),
          icon: const Icon(Icons.qr_code, color: AppColors.primaryBrand, size: 18),
          label: const Text(
            'Claim Device',
            style: TextStyle(
              color: AppColors.primaryBrand,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _showScanSheet(context, bleService),
          icon: const Icon(Icons.bluetooth, color: AppColors.primaryBrand, size: 18),
          label: const Text(
            'Provision BLE',
            style: TextStyle(
              color: AppColors.primaryBrand,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BLEService bleService, ACProvider acProvider) {
    final isOnline = acProvider.selectedDevice?['online'] ?? false;
    return AppBar(
      title: const Text(
        'AC Control',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Cloud Status Badge
        if (acProvider.selectedDevice != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.statusGreen : AppColors.statusRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isOnline ? Icons.cloud : Icons.cloud_off,
                      size: 16,
                      color: isOnline ? AppColors.primaryBrand : AppColors.textSecondary,
                    ),
                  ],
                ),
                Text(
                  isOnline ? 'CLOUD ACTIVE' : 'CLOUD OFFLINE',
                  style: TextStyle(
                    fontSize: 8,
                    color: isOnline ? AppColors.primaryBrand : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

        // Wi-Fi Config (if BLE connected)
        if (bleService.isConnected)
          IconButton(
            icon: Icon(
              acProvider.isWifiConnected ? Icons.wifi : Icons.wifi_off,
              color: acProvider.isWifiConnected ? AppColors.statusGreen : AppColors.textSecondary, 
              size: 22
            ),
            onPressed: () => _showWifiConfigDialog(context, bleService),
            tooltip: acProvider.isWifiConnected ? 'Wi-Fi Connected' : 'Wi-Fi Disconnected',
          ),

        // Bluetooth connection indicator
        if (bleService.isConnected)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.statusGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.bluetooth,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const Text(
                  'BLE CONN',
                  style: TextStyle(
                    fontSize: 8,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection(String deviceName, ACProvider acProvider) {
    String badgeText;
    Color badgeColor;
    IconData badgeIcon;

    switch (acProvider.presenceStatus) {
      case 'MOVING':
        badgeText = 'Moving Target';
        badgeColor = AppColors.statusGreen;
        badgeIcon = Icons.directions_walk;
        break;
      case 'STATIC':
        badgeText = 'Static Target';
        badgeColor = AppColors.primaryBrand;
        badgeIcon = Icons.person;
        break;
      case 'BOTH':
        badgeText = 'Moving & Static';
        badgeColor = AppColors.primaryBrand;
        badgeIcon = Icons.group;
        break;
      case 'YES':
        badgeText = 'Person Detected';
        badgeColor = AppColors.statusGreen;
        badgeIcon = Icons.person;
        break;
      default:
        badgeText = 'No Presence';
        badgeColor = AppColors.textSecondary;
        badgeIcon = Icons.person_outline;
        break;
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              _ACUnitIcon(),
              const SizedBox(height: 10),
              Text(
                deviceName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Power Banner ─────────────────────────────────────────────────────────

  Widget _buildPowerBanner(ACProvider acProvider, BLEService bleService) {
    final isOnline = acProvider.selectedDevice?['online'] ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppStyles.softShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acProvider.isAcOn ? 'AC IS ON' : 'AC IS OFF',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: acProvider.isAcOn ? AppColors.statusGreen : AppColors.textSecondary,
                  ),
                ),
                if (!isOnline)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Unit is Offline (Cloud control unavailable)',
                      style: TextStyle(fontSize: 10, color: AppColors.statusRed, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: acProvider.isAcOn,
            activeTrackColor: AppColors.primaryBrand,
            onChanged: !isOnline
                ? null
                : (val) async {
                    final success = await acProvider.controlCloudDevicePower(val);
                    if (mounted && !success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update power state.'),
                          backgroundColor: AppColors.statusRed,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  // ── Timing Section ──────────────────────────────────────────────────────

  Widget _buildTimingSection(BLEService bleService, ACProvider acProvider) {
    final showTimingControls = bleService.isConnected;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Auto Timing Config',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (!showTimingControls)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bluetooth_searching, size: 10, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Read-Only (Cloud)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 70, child: Text('ON Delay', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Expanded(
                child: Slider(
                  value: _onDelayMin,
                  min: 0.5, max: 30, divisions: 59,
                  label: '${_onDelayMin.toStringAsFixed(1)} min',
                  activeColor: AppColors.primaryBrand,
                  onChanged: showTimingControls ? (v) => setState(() => _onDelayMin = v) : null,
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${_onDelayMin.toStringAsFixed(1)}m',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 70, child: Text('OFF Delay', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Expanded(
                child: Slider(
                  value: _offDelayMin,
                  min: 0.5, max: 30, divisions: 59,
                  label: '${_offDelayMin.toStringAsFixed(1)} min',
                  activeColor: AppColors.statusRed,
                  onChanged: showTimingControls ? (v) => setState(() => _offDelayMin = v) : null,
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${_offDelayMin.toStringAsFixed(1)}m',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showTimingControls)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final onMs = (_onDelayMin * 60000).round();
                  final offMs = (_offDelayMin * 60000).round();
                  bleService.setTiming(onMs, offMs);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Timing set: ON after ${_onDelayMin.toStringAsFixed(1)} min, OFF after ${_offDelayMin.toStringAsFixed(1)} min'),
                      backgroundColor: AppColors.statusGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Save Timing over BLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Connect directly to device via Bluetooth to adjust timing limits.',
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Claim QR Dialog Simulation ──────────────────────────────────────────

  void _showQRClaimDialog(BuildContext context, ACProvider acProvider) {
    final devIdController = TextEditingController();
    bool isClaiming = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Claim AC Unit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simulated Scanner Box
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryBrand.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 60, color: AppColors.textSecondary),
                      // Scanner Laser Simulation Line
                      Positioned(
                        top: 50,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          color: AppColors.statusRed,
                        ),
                      ),
                      const Positioned(
                        bottom: 12,
                        child: Text(
                          '[Camera Scanner Simulator]',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter the Device ID found on your AC Automation controller\'s label:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: devIdController,
                  decoration: InputDecoration(
                    labelText: 'Device ID (e.g. AC_1CC3ABC25754)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.secondaryBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Simulated scan shortcuts:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        devIdController.text = 'AC_1CC3ABC25754';
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('AC_1CC3ABC25754', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        devIdController.text = 'AC_TEST_UNIT';
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('AC_TEST_UNIT', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isClaiming
                  ? null
                  : () async {
                      final val = devIdController.text.trim();
                      if (val.isEmpty) return;
                      
                      setDialogState(() => isClaiming = true);
                      final success = await acProvider.claimCloudDevice(val);
                      setDialogState(() => isClaiming = false);

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Device claimed successfully!' : 'Failed to claim device.'),
                            backgroundColor: success ? AppColors.statusGreen : AppColors.statusRed,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isClaiming
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Claim Device', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add New AC Dialog ───────────────────────────────────────────────────

  void _showAddACDialog(BuildContext context, BLEService bleService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New AC'),
        content: const Text(
          'This will clear the existing AC configuration on the device and start fresh. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final acProvider = Provider.of<ACProvider>(context, listen: false);
              final router = GoRouter.of(context);
              if (bleService.isConnected) {
                await bleService.clearDeviceConfig();
              }
              // Also clear local profiles
              final profiles = List.of(acProvider.profiles);
              for (final p in profiles) {
                await acProvider.deleteProfile(p.id);
              }
              if (mounted) {
                router.push('/setup');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBrand),
            child: const Text('Clear & Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Wi-Fi Config Dialog ─────────────────────────────────────────────────

  void _showWifiConfigDialog(BuildContext context, BLEService bleService) {
    final ssidController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure AC Wi-Fi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Wi-Fi credentials to let the AC log data to the cloud.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ssidController,
              decoration: InputDecoration(
                labelText: 'Wi-Fi Name (SSID)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.secondaryBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.secondaryBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ssid = ssidController.text.trim();
              final pass = passController.text;
              if (ssid.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await bleService.setWiFi(ssid, pass);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Wi-Fi credentials sent!' : 'Failed to send to device'),
                      backgroundColor: success ? AppColors.statusGreen : AppColors.statusRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save & Connect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.tune_rounded, 'Controls'),
      (Icons.schedule_rounded, 'Schedule'),
      (Icons.person_outline_rounded, 'Profiles'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _navIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _navIndex = i);
                  if (i == 1) {
                    final acProvider = Provider.of<ACProvider>(context, listen: false);
                    final profile = acProvider.profiles.isNotEmpty ? acProvider.profiles.first : null;
                    if (profile != null) {
                      context.push('/control', extra: profile);
                    }
                  }
                  if (i == 3) context.push('/setup');
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].$1,
                      size: 24,
                      color: active
                          ? AppColors.primaryBrand
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? AppColors.primaryBrand
                            : AppColors.textSecondary,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Scan Sheet ────────────────────────────────────────────────────────────

  void _showScanSheet(BuildContext context, BLEService bleService) {
    bleService.startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: bleService,
        child: const _ScanSheet(),
      ),
    ).then((_) => bleService.stopScan());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppStyles.softShadow],
      ),
      child: child,
    );
  }
}

// ── AC Unit Line-Art Icon ─────────────────────────────────────────────────────

class _ACUnitIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 56,
      child: CustomPaint(painter: _ACLinePainter()),
    );
  }
}

class _ACLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Body outline
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.15, w, h * 0.6),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, paint);

    // Vent lines
    for (int i = 0; i < 4; i++) {
      final x = w * 0.18 + i * w * 0.18;
      canvas.drawLine(
        Offset(x, h * 0.35),
        Offset(x, h * 0.6),
        paint,
      );
    }

    // Front panel divider
    canvas.drawLine(
      Offset(0, h * 0.38),
      Offset(w, h * 0.38),
      paint,
    );

    // Legs
    canvas.drawLine(Offset(w * 0.25, h * 0.75), Offset(w * 0.25, h), paint);
    canvas.drawLine(Offset(w * 0.75, h * 0.75), Offset(w * 0.75, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ── Scan Bottom Sheet ─────────────────────────────────────────────────────────

class _ScanSheet extends StatelessWidget {
  const _ScanSheet();

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nearby Devices',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (bleService.isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBrand,
                    ),
                  )
                else
                  TextButton(
                    onPressed: bleService.startScan,
                    child: const Text('Rescan'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: bleService.scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 48,
                          color: AppColors.primaryBrand.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bleService.isScanning
                              ? 'Searching for devices...'
                              : 'No devices found. Try rescanning.',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: bleService.scanResults.length,
                    itemBuilder: (context, index) {
                      final result = bleService.scanResults[index];
                      return BLEDeviceTile(
                        result: result,
                        onConnect: () {
                          Navigator.of(context).pop();
                          bleService.connectTo(result.device);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
