import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/auth_provider.dart';
import 'dart:ui';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id ?? 'guest';
      context.read<NotificationProvider>().fetchNotifications(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: AppColors.background.withOpacity(0.5)),
          ),
        ),
        title: const Text('Smart Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              notificationProvider.markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All caught up!')));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brandColor.withOpacity(0.1), AppColors.background],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: notificationProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : notificationProvider.notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text('All Caught Up!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('You have no new notifications.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        _buildSectionHeader('Today'),
                        ...notificationProvider.notifications.take(3).map((n) => _buildNotificationCard(n, brandColor)).toList(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Yesterday'),
                        ...notificationProvider.notifications.skip(3).map((n) => _buildNotificationCard(n, brandColor)).toList(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notif, Color brandColor) {
    final bool isUnread = !notif.isRead;
    final IconData icon = _getIconForType(notif.type.name);
    final Color iconBgColor = _getColorForType(notif.type.name, brandColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnread ? iconBgColor.withOpacity(0.2) : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isUnread ? iconBgColor : Colors.white54, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        _getTime(notif.createdAt),
                        style: TextStyle(color: isUnread ? brandColor : Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.message,
                    style: TextStyle(color: isUnread ? Colors.white70 : Colors.white54, fontSize: 14),
                  ),
                  if (notif.type.name == 'charging_completed' && isUnread) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success.withOpacity(0.2),
                        foregroundColor: AppColors.success,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      child: const Text('View Analytics'),
                    ),
                  ],
                  if (notif.type.name == 'low_balance' && isUnread) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerRed.withOpacity(0.2),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      child: const Text('Add Money'),
                    ),
                  ]
                ],
              ),
            ),
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: brandColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: brandColor.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _getIconForType(String type) {
    if (type.contains('charging')) return Icons.bolt;
    if (type.contains('wallet') || type.contains('low_balance')) return Icons.account_balance_wallet;
    if (type.contains('trip')) return Icons.map;
    if (type.contains('battery')) return Icons.battery_alert;
    return Icons.notifications;
  }
  
  Color _getColorForType(String type, Color brandColor) {
    if (type.contains('charging')) return AppColors.success;
    if (type.contains('low_balance')) return AppColors.dangerRed;
    if (type.contains('wallet')) return Colors.blue;
    if (type.contains('battery')) return Colors.orange;
    return brandColor;
  }
}
