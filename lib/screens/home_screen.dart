import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/widgets/ble_device_tile.dart';
import 'package:ac_automation/widgets/status_indicator.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to BLE status messages and update the AC provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final acProvider = Provider.of<ACProvider>(context, listen: false);
      
      bleService.statusStream.listen((message) {
        acProvider.updateFromStatus(message);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final acProvider  = Provider.of<ACProvider>(context);
    final bleService  = Provider.of<BLEService>(context);
    final profiles    = acProvider.profiles;

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          // Connection status badge
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: StatusIndicator(
                state: bleService.state,
                deviceName: bleService.device?.platformName,
              ),
            ),
          ),
          // BLE button: shows scan or disconnect based on state
          IconButton(
            icon: Icon(
              bleService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: bleService.isConnected
                  ? AppColors.statusGreen
                  : AppColors.textSecondary,
            ),
            onPressed: bleService.isConnected
                ? () => bleService.disconnect()
                : () => _showScanSheet(context, bleService),
          ),
        ],
      ),
      body: bleService.isConnected
          ? (profiles.isEmpty
              ? _buildEmptyState(context)
              : _buildDeviceGrid(context, acProvider, bleService))
          : _buildConnectPrompt(context, bleService),
      floatingActionButton: bleService.isConnected
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/setup'),
              backgroundColor: AppColors.primaryBrand,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add AC', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  // ---------- Connect Prompt (not yet connected) ----------

  Widget _buildConnectPrompt(BuildContext context, BLEService bleService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: AppColors.primaryBrand.withValues(alpha: 0.4),
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
          const SizedBox(height: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Scan Bottom Sheet ----------

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

  // ---------- Empty State (connected but no profiles) ----------

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ac_unit, size: 100, color: AppColors.secondaryAccent),
          const SizedBox(height: 24),
          const Text(
            'No ACs found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add your first AC to start automating',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.push('/setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Add New AC',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Device Grid ----------

  Widget _buildDeviceGrid(
      BuildContext context, ACProvider provider, BLEService bleService) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: provider.profiles.length,
      itemBuilder: (context, index) {
        final profile = provider.profiles[index];
        return _buildDeviceCard(context, profile, provider);
      },
    );
  }

  Widget _buildDeviceCard(
      BuildContext context, dynamic profile, ACProvider provider) {
    return GestureDetector(
      onTap: () => context.push('/control', extra: profile),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [AppStyles.softShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.ac_unit,
                    color: AppColors.primaryBrand, size: 28),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.statusRed, size: 22),
                      onPressed: () => _showDeleteDialog(context, profile, provider),
                      constraints: const BoxConstraints(),
                    ),
                    Switch(
                      value: true,
                      onChanged: (val) {},
                      activeThumbColor: AppColors.primaryBrand,
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: provider.isPresenceDetected
                          ? AppColors.statusGreen
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.isPresenceDetected ? 'Present' : 'Empty',
                      style: TextStyle(
                        color: provider.isPresenceDetected
                            ? AppColors.statusGreen
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.brand} • ${profile.model ?? ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic profile, ACProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteProfile(profile.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );
  }
}

// ---------- Scan Bottom Sheet Widget ----------

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
          // Handle bar
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
                          style: const TextStyle(color: AppColors.textSecondary),
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