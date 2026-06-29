import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/services/auth_service.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/utils/constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final acProvider = Provider.of<ACProvider>(context);
    final user = authService.currentUser;
    final email = user?['email'] ?? 'user@avio.com';
    final name = user?['username'] ?? 'AVIO User';

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [AppStyles.softShadow],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primaryBrand.withOpacity(0.1),
                    child: Text(
                      name.substring(0, name.length.clamp(0, 1)).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBrand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Rows
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Devices Claimed',
                    value: '${acProvider.cloudDevices.length}',
                    iconWidget: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        AppColors.primaryBrand,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/20.png',
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                      ),
                    ),
                    color: AppColors.primaryBrand,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Active Profiles',
                    value: '${acProvider.profiles.length}',
                    iconWidget: Icon(
                      Icons.dashboard_customize_outlined,
                      color: AppColors.secondaryAccent,
                      size: 18,
                    ),
                    color: AppColors.secondaryAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Items
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [AppStyles.softShadow],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text(
                      'App Preferences',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text(
                      'Security & Privacy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text(
                      'Help & Support',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: AppColors.statusRed,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: AppColors.statusRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      context.pop(); // Pop profile screen
                      await authService.logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Widget iconWidget,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppStyles.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: iconWidget,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
