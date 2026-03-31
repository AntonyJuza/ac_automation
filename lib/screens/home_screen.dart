import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/widgets/ble_device_tile.dart';
import 'package:ac_automation/widgets/ac_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  double _onDelayMin = 1.0;
  double _offDelayMin = 5.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = Provider.of<BLEService>(context, listen: false);
      final ac = Provider.of<ACProvider>(context, listen: false);
      ble.statusStream.listen((msg) { if (mounted) ac.updateFromStatus(msg); });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BLEService>(context);
    final ac = Provider.of<ACProvider>(context);
    final profile = ac.profiles.isNotEmpty ? ac.profiles.first : null;
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: _buildAppBar(ble),
      body: ble.isConnected
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildHeroSection(
                  ac.configName.isNotEmpty ? ac.configName : (profile?.name ?? 'Living Room AC'),
                  ac,
                ),
                const SizedBox(height: 16),
                _buildTimingSection(ble),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  TextButton.icon(
                    onPressed: () => _showAddACDialog(context, ble),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBrand, size: 18),
                    label: const Text('Add New AC', style: TextStyle(color: AppColors.primaryBrand, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showScanSheet(context, ble),
                    icon: const Icon(Icons.bluetooth, color: AppColors.primaryBrand, size: 18),
                    label: const Text('Manage Devices', style: TextStyle(color: AppColors.primaryBrand, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ]),
              ]),
            )
          : _buildConnectPrompt(context, ble),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BLEService ble) {
    return AppBar(
      backgroundColor: AppColors.primaryBackground,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.menu, color: AppColors.textPrimary), onPressed: () {}),
      title: const Text('AC Control', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      actions: [
        if (ble.isConnected)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.statusGreen, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Icon(Icons.bluetooth, size: 16, color: AppColors.textSecondary),
              ]),
              const Text('CONNECTED', style: TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {},
            child: const CircleAvatar(radius: 17, backgroundColor: AppColors.textPrimary,
              child: Text('SJ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
        ),
      ],
    );
  }

  // ── Hero Section ──────────────────────────────────────────────────────────

  Widget _buildHeroSection(String deviceName, ACProvider ac) {
    String badgeText; Color badgeColor; IconData badgeIcon;
    switch (ac.presenceStatus) {
      case 'MOVING': badgeText = 'Moving Target'; badgeColor = AppColors.statusGreen; badgeIcon = Icons.directions_walk; break;
      case 'STATIC': badgeText = 'Static Target'; badgeColor = AppColors.primaryBrand; badgeIcon = Icons.person; break;
      case 'BOTH':   badgeText = 'Moving & Static'; badgeColor = AppColors.primaryBrand; badgeIcon = Icons.group; break;
      case 'YES':    badgeText = 'Person Detected'; badgeColor = AppColors.statusGreen; badgeIcon = Icons.person; break;
      default:       badgeText = 'No Presence'; badgeColor = AppColors.textSecondary; badgeIcon = Icons.person_outline;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppStyles.softShadow],
      ),
      child: Stack(alignment: Alignment.center, children: [
        // Diffuse glow blobs
        Positioned(top: 0, left: 30,
          child: _GlowBlob(color: AppColors.primaryBrand.withValues(alpha: 0.10), size: 100)),
        Positioned(top: 8, right: 30,
          child: _GlowBlob(color: AppColors.secondaryAccent.withValues(alpha: 0.09), size: 80)),
        // Content
        Column(children: [
          AcActiveCoolIcon(size: 180, color: AppColors.textPrimary.withValues(alpha: 0.82)),
          const SizedBox(height: 10),
          Text(deviceName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _PowerPill(isOn: ac.isAcOn),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(badgeIcon, size: 13, color: badgeColor),
              const SizedBox(width: 4),
              Text(badgeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── Timing Section ────────────────────────────────────────────────────────

  Widget _buildTimingSection(BLEService ble) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Auto Timing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _GradientSliderRow(
          label: 'ON Delay',
          value: _onDelayMin,
          gradientColors: const [AppColors.primaryBrand, AppColors.secondaryAccent],
          onChanged: (v) => setState(() => _onDelayMin = v),
        ),
        const SizedBox(height: 2),
        _GradientSliderRow(
          label: 'OFF Delay',
          value: _offDelayMin,
          gradientColors: const [Color(0xFFEF4444), Color(0xFFF97316)],
          onChanged: (v) => setState(() => _offDelayMin = v),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ble.setTiming((_onDelayMin * 60000).round(), (_offDelayMin * 60000).round());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Timing set: ON ${_onDelayMin.toStringAsFixed(1)} min / OFF ${_offDelayMin.toStringAsFixed(1)} min'),
                backgroundColor: AppColors.statusGreen,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              elevation: 0,
            ),
            child: const Text('Save Timing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Connect Prompt ────────────────────────────────────────────────────────

  Widget _buildConnectPrompt(BuildContext context, BLEService ble) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bluetooth_searching, size: 80, color: AppColors.primaryBrand.withValues(alpha: 0.35)),
        const SizedBox(height: 24),
        const Text('No Device Connected', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        const Text('Connect to your AC Automation\ndevice to get started.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => _showScanSheet(context, ble),
          icon: const Icon(Icons.bluetooth, color: Colors.white),
          label: const Text('Scan for Devices', style: TextStyle(color: Colors.white, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrand,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    );
  }

  // ── Add New AC Dialog ─────────────────────────────────────────────────────

  void _showAddACDialog(BuildContext context, BLEService ble) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New AC'),
        content: const Text('This will clear the existing AC configuration on the device and start fresh. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ac = Provider.of<ACProvider>(context, listen: false);
              final router = GoRouter.of(context);
              if (ble.isConnected) await ble.clearDeviceConfig();
              for (final p in List.of(ac.profiles)) await ac.deleteProfile(p.id);
              if (mounted) router.push('/setup');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBrand),
            child: const Text('Clear & Continue', style: TextStyle(color: Colors.white)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _navIndex == i;
              return GestureDetector(
                onTap: () { setState(() => _navIndex = i); if (i == 3) context.push('/setup'); },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(items[i].$1, size: 24, color: active ? AppColors.primaryBrand : AppColors.textSecondary),
                  const SizedBox(height: 3),
                  Text(items[i].$2, style: TextStyle(fontSize: 11,
                      color: active ? AppColors.primaryBrand : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Scan Sheet ────────────────────────────────────────────────────────────

  void _showScanSheet(BuildContext context, BLEService ble) {
    ble.startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(value: ble, child: const _ScanSheet()),
    ).then((_) => ble.stopScan());
  }

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

// ── Glow Blob ─────────────────────────────────────────────────────────────────

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: size * 0.8, spreadRadius: size * 0.2)],
      ),
    );
  }
}

// ── Power Pill ────────────────────────────────────────────────────────────────

class _PowerPill extends StatelessWidget {
  final bool isOn;
  const _PowerPill({required this.isOn});

  @override
  Widget build(BuildContext context) {
    final color = isOn ? AppColors.statusGreen : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(isOn ? 'AC ON' : 'AC OFF',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.4)),
        const SizedBox(width: 8),
        CupertinoSwitch(
          value: isOn,
          activeTrackColor: AppColors.primaryBrand,
          onChanged: null, // passive indicator — ESP radar controls this
        ),
      ]),
    );
  }
}

// ── Gradient Slider Row ───────────────────────────────────────────────────────

class _GradientSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  const _GradientSliderRow({
    required this.label,
    required this.value,
    required this.gradientColors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 68, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: gradientColors.first,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            thumbColor: gradientColors.first,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            min: 0.5, max: 30, divisions: 59,
            label: '${value.toStringAsFixed(1)} min',
            onChanged: onChanged,
          ),
        ),
      ),
      SizedBox(
        width: 46,
        child: Text('${value.toStringAsFixed(1)}m',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
    ]);
  }
}

// ── Scan Bottom Sheet ─────────────────────────────────────────────────────────

class _ScanSheet extends StatelessWidget {
  const _ScanSheet();

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BLEService>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Nearby Devices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            if (ble.isScanning)
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrand))
            else
              TextButton(onPressed: ble.startScan, child: const Text('Rescan')),
          ]),
        ),
        Expanded(
          child: ble.scanResults.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bluetooth_searching, size: 48, color: AppColors.primaryBrand.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(ble.isScanning ? 'Searching for devices...' : 'No devices found. Try rescanning.',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ]))
              : ListView.builder(
                  itemCount: ble.scanResults.length,
                  itemBuilder: (context, i) {
                    final result = ble.scanResults[i];
                    return BLEDeviceTile(
                      result: result,
                      onConnect: () { Navigator.of(context).pop(); ble.connectTo(result.device); },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
