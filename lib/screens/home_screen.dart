import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/widgets/ble_device_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  // Timing controls (in minutes for UI, sent as ms)
  double _onDelayMin = 1.0;
  double _offDelayMin = 5.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final acProvider = Provider.of<ACProvider>(context, listen: false);
      bleService.statusStream.listen((msg) {
        if (mounted) acProvider.updateFromStatus(msg);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleService = Provider.of<BLEService>(context);
    final acProvider = Provider.of<ACProvider>(context);
    final profile = acProvider.profiles.isNotEmpty ? acProvider.profiles.first : null;

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: _buildAppBar(bleService),
      body: bleService.isConnected
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(
                    acProvider.configName.isNotEmpty 
                        ? acProvider.configName 
                        : (profile?.name ?? 'Living Room AC'),
                    acProvider,
                  ),
                  const SizedBox(height: 16),
                  _buildPowerBanner(acProvider, bleService),
                  const SizedBox(height: 16),
                  _buildTimingSection(bleService),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showAddACDialog(context, bleService),
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBrand, size: 18),
                        label: const Text(
                          'Add New AC',
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
                          'Manage Devices',
                          style: TextStyle(
                            color: AppColors.primaryBrand,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : _buildConnectPrompt(context, bleService),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BLEService bleService) {
    return AppBar(
      backgroundColor: AppColors.primaryBackground,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: AppColors.textPrimary),
        onPressed: () {},
      ),
      title: const Text(
        'AC Control',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Connection status
        if (bleService.isConnected)
          Padding(
            padding: const EdgeInsets.only(right: 4),
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
                  'CONNECTED',
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
        // Avatar
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {},
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.textPrimary,
              child: const Text(
                'SJ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
          Text(
            acProvider.isAcOn ? 'AC IS ON' : 'AC IS OFF',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: acProvider.isAcOn ? AppColors.statusGreen : AppColors.textSecondary,
            ),
          ),
          CupertinoSwitch(
            value: acProvider.isAcOn,
            activeTrackColor: AppColors.primaryBrand,
            onChanged: (val) {
              // The switch is a passive indicator since the ESP's radar controls it!
            },
          ),
        ],
      ),
    );
  }
  // ── Timing Section ──────────────────────────────────────────────────────

  Widget _buildTimingSection(BLEService bleService) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Auto Timing',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
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
                  onChanged: (v) => setState(() => _onDelayMin = v),
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
                  onChanged: (v) => setState(() => _offDelayMin = v),
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
              child: const Text('Save Timing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
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


  // ── Connect Prompt ────────────────────────────────────────────────────────

  Widget _buildConnectPrompt(BuildContext context, BLEService bleService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: AppColors.primaryBrand.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Device Connected',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connect to your AC Automation\ndevice to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showScanSheet(context, bleService),
            icon: const Icon(Icons.bluetooth, color: Colors.white),
            label: const Text(
              'Scan for Devices',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
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
