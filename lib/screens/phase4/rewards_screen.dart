import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reward_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import 'package:intl/intl.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id ?? 'guest';
      context.read<RewardProvider>().fetchUserRewards(userId);
      context.read<ProfileProvider>().loadProfile(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rewardProvider = context.watch<RewardProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('EVHub Rewards')),
      body: rewardProvider.isLoading || profileProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.stars, size: 64, color: AppColors.primaryCyan),
                          const SizedBox(height: 16),
                          const Text('Total Reward Points', style: TextStyle(fontSize: 16)),
                          Text(
                            '${profileProvider.profile?.totalRewardPoints ?? 0}',
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primaryCyan),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.card_giftcard),
                            label: const Text('Redeem Points'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('Recent History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
                rewardProvider.rewards.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text('No rewards earned yet.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final reward = rewardProvider.rewards[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primaryCyan.withOpacity(0.2),
                                      child: const Icon(Icons.bolt, color: AppColors.primaryCyan),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(DateFormat('MMM dd, hh:mm a').format(reward.timestamp), style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    Text('+${reward.points}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: rewardProvider.rewards.length,
                        ),
                      ),
              ],
            ),
    );
  }
}
