import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import 'maps_screen.dart';
import 'reservation_screen.dart';
import 'profile_screen.dart';
import 'rewards_screen.dart';
import 'community_screen.dart';

class Phase4Dashboard extends StatelessWidget {
  const Phase4Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live EV Ecosystem'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Production Modules', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildModuleCard(context, 'Live Map', Icons.map, const MapsScreen(), isDark),
                _buildModuleCard(context, 'Reservations', Icons.schedule, const ReservationScreen(), isDark),
                _buildModuleCard(context, 'Live Profile', Icons.person, const ProfileScreen(), isDark),
                _buildModuleCard(context, 'Rewards', Icons.stars, const RewardsScreen(), isDark),
                _buildModuleCard(context, 'Community', Icons.groups, const CommunityScreen(), isDark),
                _buildModuleCard(context, 'Live Wallet', Icons.account_balance_wallet, const Scaffold(body: Center(child: Text('Live Wallet (WIP)'))), isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, String title, IconData icon, Widget destination, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.primaryPurple),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
