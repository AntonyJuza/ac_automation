import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final acProvider = Provider.of<ACProvider>(context);
    final profiles = acProvider.profiles;

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bluetooth, 
              color: acProvider.isConnected ? AppColors.statusGreen : AppColors.textSecondary
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: profiles.isEmpty 
          ? _buildEmptyState(context)
          : _buildDeviceGrid(context, acProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/setup'),
        backgroundColor: AppColors.primaryBrand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add AC', style: TextStyle(color: Colors.white)),
      ),
    );
  }

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add New AC', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceGrid(BuildContext context, ACProvider provider) {
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

  Widget _buildDeviceCard(BuildContext context, dynamic profile, ACProvider provider) {
    return GestureDetector(
      onTap: () => context.push('/control'),
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
                const Icon(Icons.ac_unit, color: AppColors.primaryBrand, size: 28),
                Switch(
                  value: true,
                  onChanged: (val) {},
                  activeThumbColor: AppColors.primaryBrand,
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
                      color: provider.isPresenceDetected ? AppColors.statusGreen : AppColors.textSecondary
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.isPresenceDetected ? 'Present' : 'Empty',
                      style: TextStyle(
                        color: provider.isPresenceDetected ? AppColors.statusGreen : AppColors.textSecondary,
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
}
