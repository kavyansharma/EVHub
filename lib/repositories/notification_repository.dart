import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationRepository {
  final NotificationService _notificationService;

  NotificationRepository({required NotificationService notificationService})
      : _notificationService = notificationService;

  Future<List<NotificationModel>> fetchUserNotifications(String userId) async {
    return await _notificationService.fetchNotifications(userId);
  }
}
