import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

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

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Profile')),
      body: profileProvider.isLoading || profileProvider.profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHeader(user?.name ?? 'Guest User', user?.email ?? '', isDark),
                  const SizedBox(height: 24),
                  _buildStatRow(profileProvider.profile!),
                  const SizedBox(height: 24),
                  _buildBadgesSection(profileProvider.profile!.badges, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String name, String email, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryCyan.withOpacity(0.2),
            child: const Icon(Icons.person, size: 40, color: AppColors.primaryCyan),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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
        Expanded(child: _buildStatCard('Sessions', '${profile.totalSessions}', Icons.ev_station)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Charged', '${profile.totalKwhCharged} kWh', Icons.bolt)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Tier', profile.membershipTier, Icons.star)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(List<String> badges, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earned Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (badges.isEmpty)
            Text('No badges yet. Keep charging to earn them!', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          if (badges.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges.map((b) => Chip(
                label: Text(b),
                backgroundColor: AppColors.primaryCyan.withOpacity(0.1),
                side: const BorderSide(color: AppColors.primaryCyan),
              )).toList(),
            )
        ],
      ),
    );
  }
}
