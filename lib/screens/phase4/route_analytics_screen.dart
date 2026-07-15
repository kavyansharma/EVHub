import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/route_analytics_provider.dart';
import '../../models/route_analytics_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class RouteAnalyticsScreen extends StatefulWidget {
  const RouteAnalyticsScreen({super.key});

  @override
  State<RouteAnalyticsScreen> createState() => _RouteAnalyticsScreenState();
}

class _RouteAnalyticsScreenState extends State<RouteAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteAnalyticsProvider>().loadAnalytics('demo_user_123');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteAnalyticsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Post-Trip Analytics')),
      body: provider.history.isEmpty
          ? const Center(child: Text('No trip analytics found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: provider.history.length,
              itemBuilder: (context, index) {
                final analytics = provider.history[index];
                return _buildAnalyticsCard(analytics, isDark);
              },
            ),
    );
  }

  Widget _buildAnalyticsCard(RouteAnalyticsModel analytics, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: AppColors.primaryPurple, size: 28),
                const SizedBox(width: 12),
                const Text('Trip Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(analytics.completedAt.toString().split(' ')[0], style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Energy Used', '${analytics.actualEnergyKwh.toStringAsFixed(1)} kWh', Icons.electric_bolt, Colors.amber),
                _buildMetric('Savings', '₹${analytics.costSavingsInr.toStringAsFixed(0)}', Icons.savings, Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Avg Speed', '${analytics.averageSpeedKmh.toStringAsFixed(0)} km/h', Icons.speed, AppColors.primaryCyan),
                _buildMetric('CO2 Saved', '${analytics.co2SavedKg.toStringAsFixed(1)} kg', Icons.eco, Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 24),
            _buildAccuracyBar(analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildAccuracyBar(RouteAnalyticsModel analytics) {
    final diff = analytics.actualEnergyKwh - analytics.predictedEnergyKwh;
    final isMore = diff > 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Prediction Accuracy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (analytics.predictedEnergyKwh / (analytics.predictedEnergyKwh + diff.abs())).clamp(0.0, 1.0),
          backgroundColor: Colors.grey.withOpacity(0.3),
          color: isMore ? Colors.redAccent : Colors.green,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          isMore
              ? 'Used ${diff.toStringAsFixed(1)} kWh MORE than predicted.'
              : 'Used ${diff.abs().toStringAsFixed(1)} kWh LESS than predicted.',
          style: TextStyle(color: isMore ? Colors.redAccent : Colors.green, fontSize: 12),
        )
      ],
    );
  }
}
