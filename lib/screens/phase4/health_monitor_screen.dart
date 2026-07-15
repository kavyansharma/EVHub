import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/health_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class HealthMonitorScreen extends StatefulWidget {
  const HealthMonitorScreen({super.key});

  @override
  State<HealthMonitorScreen> createState() => _HealthMonitorScreenState();
}

class _HealthMonitorScreenState extends State<HealthMonitorScreen> {
  @override
  void initState() {
    super.initState();
    // In a real app we'd get the actual vehicle ID from the GarageProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthProvider>().loadHealthData('demo_vehicle_123');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final health = provider.healthData;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('EV Health Monitor')),
      body: health == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrimaryHealth(health),
                  const SizedBox(height: 24),
                  _buildSecondaryMetrics(health),
                  const SizedBox(height: 24),
                  const Text('AI Recommendations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...provider.recommendations.map((r) => _buildRecommendationCard(r, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildPrimaryHealth(HealthModel health) {
    Color healthColor = health.stateOfHealth > 90.0
        ? Colors.green
        : health.stateOfHealth > 80.0
            ? Colors.orange
            : Colors.red;

    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text('Battery State of Health (SOH)', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: health.stateOfHealth / 100.0,
                    strokeWidth: 12,
                    color: healthColor,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                  ),
                ),
                Text(
                  '${health.stateOfHealth.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: healthColor),
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              health.stateOfHealth > 90.0 ? 'Excellent Condition' : 'Degradation Detected',
              style: TextStyle(color: healthColor, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryMetrics(HealthModel health) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Cycle Count', '${health.cycleCount}', Icons.autorenew, AppColors.primaryCyan),
        _buildMetricCard('Behavior Score', '${health.chargingBehaviorScore}', Icons.star, Colors.amber),
        _buildMetricCard('Efficiency', '${health.averageChargingEfficiency}%', Icons.bolt, Colors.green),
        _buildMetricCard('Degradation/mo', '${health.monthlyDegradationRate}%', Icons.trending_down, Colors.redAccent),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primaryCyan),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
