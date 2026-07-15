import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import 'garage_screen.dart';
import 'battery_health_screen.dart';
import 'notification_screen.dart';
// import 'calculator_screen.dart';
// import 'history_screen.dart';
// import 'wallet_analytics_screen.dart';
// import 'ai_assistant_screen.dart';
// import 'trip_intelligence_screen.dart';

class Phase3Dashboard extends StatelessWidget {
  const Phase3Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart EV Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Modules', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildModuleCard(context, 'My Garage', Icons.garage, const GarageScreen(), isDark),
                _buildModuleCard(context, 'Battery Health', Icons.battery_charging_full, const BatteryHealthScreen(), isDark),
                _buildModuleCard(context, 'Charging Calc', Icons.calculate, const Scaffold(body: Center(child: Text('Calculator (WIP)'))), isDark),
                _buildModuleCard(context, 'Wallet Analytics', Icons.analytics, const Scaffold(body: Center(child: Text('Analytics (WIP)'))), isDark),
                _buildModuleCard(context, 'Trip Intelligence', Icons.alt_route, const Scaffold(body: Center(child: Text('Trip Intel (WIP)'))), isDark),
                _buildModuleCard(context, 'AI Assistant', Icons.auto_awesome, const Scaffold(body: Center(child: Text('AI Assistant (WIP)'))), isDark),
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
            Icon(icon, size: 48, color: AppColors.primaryCyan),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
