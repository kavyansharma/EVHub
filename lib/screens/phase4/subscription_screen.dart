import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadSubscription('demo_user_123');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('EVHub Subscriptions')),
      body: provider.subscription == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentTierCard(provider, isDark),
                  const SizedBox(height: 24),
                  const Text('Available Plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: 'Gold Tier',
                    price: '₹499 / month',
                    features: ['10% Off All Charging', 'Standard Priority Reservations', '50 kWh Free / month'],
                    color: Colors.amber,
                    isCurrent: provider.subscription!.tier == SubscriptionTier.gold,
                    onTap: () => provider.upgradeTier(SubscriptionTier.gold),
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: 'Platinum Tier',
                    price: '₹999 / month',
                    features: ['20% Off All Charging', 'High Priority Reservations', '100 kWh Free / month', '24/7 Support'],
                    color: Colors.blueGrey.shade300,
                    isCurrent: provider.subscription!.tier == SubscriptionTier.platinum,
                    onTap: () => provider.upgradeTier(SubscriptionTier.platinum),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentTierCard(SubscriptionProvider provider, bool isDark) {
    final sub = provider.subscription!;
    final color = sub.tier == SubscriptionTier.platinum
        ? Colors.blueGrey.shade300
        : (sub.tier == SubscriptionTier.gold ? Colors.amber : Colors.grey);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.workspace_premium, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            '${sub.tier.name.toUpperCase()} TIER',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'Active until ${sub.endDate.toString().split(' ')[0]}',
            style: const TextStyle(color: Colors.grey),
          ),
          const Divider(height: 32),
          ...provider.benefits.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primaryCyan, size: 20),
                  const SizedBox(width: 12),
                  Text('${e.key}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required Color color,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryCyan, borderRadius: BorderRadius.circular(12)),
                  child: const Text('CURRENT', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 8),
          Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(f),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          if (!isCurrent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
                child: const Text('Upgrade Plan'),
              ),
            )
        ],
      ),
    );
  }
}
