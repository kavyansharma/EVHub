import '../models/notification_model.dart';

class NotificationService {
  // TODO: Integrate FirebaseMessaging
  // late final FirebaseMessaging _messaging;

  void initialize() {
    // _messaging = FirebaseMessaging.instance;
    // _messaging.requestPermission();
    // _messaging.onTokenRefresh.listen((token) {
    //   // Save token to Firestore
    // });
  }

  /// Local cache for testing without FCM.
  /// In production, this would integrate with Firebase Messaging streams.
  
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Mock notifications
    return [
      NotificationModel(
        id: 'notif_1',
        userId: userId,
        type: NotificationType.chargingCompleted,
        title: 'Charging Completed',
        message: 'Your Tata Nexon EV is fully charged.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: false,
      ),
      NotificationModel(
        id: 'notif_2',
        userId: userId,
        type: NotificationType.walletLowBalance,
        title: 'Low Wallet Balance',
        message: 'Your EVHub wallet balance is below ₹500.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationModel(
        id: 'notif_3',
        userId: userId,
        type: NotificationType.tripReminder,
        title: 'Upcoming Trip',
        message: 'Reminder: Trip to Lonavala scheduled for tomorrow.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }
}
