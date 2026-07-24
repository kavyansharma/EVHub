import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/admin_charger_provider.dart';
import '../../providers/charger_data_dashboard_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id ?? 'guest';
      context.read<ProfileProvider>().loadProfile(userId);
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminChargerProvider = Provider.of<AdminChargerProvider>(context, listen: false);
    final dashboardProvider = Provider.of<ChargerDataDashboardProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to logout of EVHub?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    final success = await authProvider.logout();

    if (success) {
      adminChargerProvider.clearState();
      dashboardProvider.clearDashboard();
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Logout failed. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PROFILE & SETTINGS', style: TextStyle(letterSpacing: 2.0, fontSize: 16)),
      ),
      body: profileProvider.isLoading || profileProvider.profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profile Header
                  _buildHeader(user?.name ?? 'EV Driver', user?.email ?? 'driver@evhub.com', user?.avatarUrl),
                  const SizedBox(height: 24),

                  // 2. Charging Stats
                  _buildStatRow(profileProvider.profile!),
                  const SizedBox(height: 24),

                  // 3. Badges List
                  _buildBadgesSection(profileProvider.profile!.badges),
                  const SizedBox(height: 24),

                  // 4. Admin Control Panel (Visible ONLY to Admin users)
                  if (user?.isAdmin == true) _buildAdminSection(context),

                  // 5. Settings Options List
                  const Text(
                    'CONTROL PANEL',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsOption(
                    title: 'Notification Preferences',
                    subtitle: 'Alerts for charging completion & queues',
                    icon: HugeIcons.strokeRoundedNotification01,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsOption(
                    title: 'Offline Map Cache',
                    subtitle: 'Download route charging stations',
                    icon: HugeIcons.strokeRoundedMapsLocation01,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsOption(
                    title: 'Connected Services',
                    subtitle: 'Manage Firebase integration & Sync',
                    icon: HugeIcons.strokeRoundedLink01,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsOption(
                    title: 'Account Security',
                    subtitle: 'Biometric authorization & Passkeys',
                    icon: HugeIcons.strokeRoundedKey01,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  
                  // 5. Logout Tile
                  InkWell(
                    key: const Key('logout_button'),
                    onTap: () => _handleLogout(context),
                    borderRadius: BorderRadius.circular(18),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedLogout01,
                              color: AppColors.danger,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logout',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sign out of EVHub account',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.danger, size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String name, String email, String? avatarUrl) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.chargingGradient,
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.card,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 36)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(dynamic profile) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Sessions', '${profile.totalSessions}', HugeIcons.strokeRoundedFuelStation, AppColors.secondary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Charged', '${profile.totalKwhCharged.toStringAsFixed(0)} kWh', HugeIcons.strokeRoundedFlash, AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Tier', profile.membershipTier, HugeIcons.strokeRoundedStar, AppColors.warning)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, List<List<dynamic>> icon, Color iconColor) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      borderRadius: 20,
      child: Column(
        children: [
          HugeIcon(icon: icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(List<String> badges) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EARNED BADGES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          if (badges.isEmpty)
            const Text('Keep charging to unlock milestones and badges.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (badges.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges.map((badge) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            )
        ],
      ),
    );
  }

  Widget _buildSettingsOption({
    required String title,
    required String subtitle,
    required List<List<dynamic>> icon,
    required Color color,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(icon: icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADMIN CONTROL PANEL',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          key: const Key('admin_dashboard_tile'),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.adminDashboard);
          },
          borderRadius: BorderRadius.circular(18),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSecurity,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View charger operations, data quality, network coverage & alerts',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

