import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/battery_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class BatteryHealthScreen extends StatefulWidget {
  const BatteryHealthScreen({super.key});

  @override
  State<BatteryHealthScreen> createState() => _BatteryHealthScreenState();
}

class _BatteryHealthScreenState extends State<BatteryHealthScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final garage = context.read<GarageProvider>();
      final auth = context.read<AuthProvider>();
      if (garage.selectedVehicle != null) {
        context.read<BatteryProvider>().loadBatteryHealth(garage.selectedVehicle!.id, auth.user?.id ?? 'guest');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batteryProvider = context.watch<BatteryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Battery Health Center')),
      body: batteryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : batteryProvider.batteryHealth == null
              ? const Center(child: Text('No battery health data available. Please select a vehicle first.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildHealthRing(batteryProvider.batteryHealth!.healthPercentage, isDark),
                      const SizedBox(height: 24),
                      _buildStatGrid(batteryProvider.batteryHealth!, isDark),
                      const SizedBox(height: 24),
                      _buildRecommendations(batteryProvider.batteryHealth!.chargingRecommendations, isDark),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHealthRing(double healthPercent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('Overall Battery Health', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: healthPercent / 100),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 12,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      color: AppColors.primaryCyan,
                    );
                  },
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${healthPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryCyan),
                  ),
                  Text('Healthy', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(dynamic healthData, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Charging Cycles', '${healthData.chargingCycles}', Icons.autorenew, isDark),
        _buildStatCard('DC Fast Charges', '${healthData.fastChargingUsage}', Icons.bolt, isDark),
        _buildStatCard('Avg Temp', '${healthData.averageBatteryTemperature}°C', Icons.thermostat, isDark),
        _buildStatCard('Est. Degradation', '${healthData.estimatedDegradation}%', Icons.trending_down, isDark),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 32),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<String> recommendations, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: AppColors.primaryCyan, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(rec, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
