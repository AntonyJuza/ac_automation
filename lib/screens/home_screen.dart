import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/auth_service.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/services/api_service.dart';
import 'package:ac_automation/models/ac_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final acProvider = Provider.of<ACProvider>(context, listen: false);

      bleService.statusStream.listen((msg) {
        if (mounted) acProvider.updateFromStatus(msg);
      });

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
    final authService = Provider.of<AuthService>(context);
    final acProvider = Provider.of<ACProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => acProvider.fetchCloudDevices(),
          color: AppColors.primaryBrand,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Custom Premium Header Section
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          'assets/20.png',
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryBrand.withOpacity(
                              0.1,
                            ),
                            child: Text(
                              (authService.currentUser?['username'] ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBrand,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Welcome home',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),

              // Device Dial Boxes Grid or Empty View
              if (acProvider.isFetchingDevices &&
                  acProvider.cloudDevices.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (acProvider.cloudDevices.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      color: AppColors.primaryBackground,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No devices yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Scan the controller\'s QR code or use BLE setup to link a device.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.95,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final device = acProvider.cloudDevices[index];
                      return _buildDeviceDialBox(context, device, acProvider);
                    }, childCount: acProvider.cloudDevices.length),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scanner'),
        backgroundColor: AppColors.primaryBrand,
        mini: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }

  // --- Device Dial Box ---
  Widget _buildDeviceDialBox(
    BuildContext context,
    Map<String, dynamic> device,
    ACProvider acProvider,
  ) {
    final deviceId = device['deviceId'] ?? '';
    final name = device['deviceName'] ?? 'Bedroom AC';
    final isOnline = device['online'] ?? false;
    final isAcOn = device['powerState'] ?? false;

    // Get matching ACProfile
    final profile = acProvider.profiles.firstWhere(
      (p) => p.id == deviceId,
      orElse: () {
        final newP = ACProfile(
          id: deviceId,
          name: name,
          brand: 'Voltas',
          buttons: {},
          createdAt: DateTime.now(),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          acProvider.addProfile(newP);
        });
        return newP;
      },
    );

    return GestureDetector(
      onTap: () {
        acProvider.selectDevice(device);
        context.push('/control', extra: profile);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row: Fan Icon + Power Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlowingFanIcon(isRunning: isOnline && isAcOn),
                GestureDetector(
                  onTap: () {}, // Swallows card tap
                  child: Transform.scale(
                    scale: 0.8,
                    child: CupertinoSwitch(
                      value: isAcOn,
                      activeTrackColor: AppColors.primaryBrand,
                      onChanged: !isOnline
                          ? null
                          : (val) async {
                              final success =
                                  await ApiService.toggleDevicePower(
                                    deviceId,
                                    val,
                                  );
                              if (success) {
                                acProvider.fetchCloudDevices();
                              }
                            },
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Customizable Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Status Dot + Active status label
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? (isAcOn
                              ? AppColors.statusGreen
                              : AppColors.textSecondary.withOpacity(0.4))
                        : AppColors.statusRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  !isOnline ? 'OFFLINE' : (isAcOn ? 'ACTIVE ON' : 'STANDBY'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isOnline
                        ? (isAcOn
                              ? AppColors.statusGreen
                              : AppColors.textSecondary)
                        : AppColors.statusRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Propeller Fan Icon Animation ---
class _GlowingFanIcon extends StatefulWidget {
  final bool isRunning;
  const _GlowingFanIcon({required this.isRunning});

  @override
  State<_GlowingFanIcon> createState() => _GlowingFanIconState();
}

class _GlowingFanIconState extends State<_GlowingFanIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    if (widget.isRunning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _GlowingFanIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isRunning
              ? AppColors.primaryBrand.withOpacity(0.08)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            widget.isRunning
                ? AppColors.primaryBrand
                : AppColors.textSecondary.withOpacity(0.4),
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/20.png',
            width: 26,
            height: 26,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
