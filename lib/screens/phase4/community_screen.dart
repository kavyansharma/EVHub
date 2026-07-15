import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('EVHub Community')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 80, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            const Text('Community Forums & Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Connect with other EV owners,\nshare reviews, and earn reputation.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 32),
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text('Coming Soon in Phase 4.2', style: TextStyle(color: AppColors.primaryCyan, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
