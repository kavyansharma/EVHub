import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  chargingCompleted,
  chargingStarted,
  walletLowBalance,
  lowBattery,
  tripReminder,
  nearbyCharger,
  maintenanceReminder,
  systemInfo,
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: _typeFromString(data['type']),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  static NotificationType _typeFromString(String? typeStr) {
    switch (typeStr) {
      case 'chargingCompleted':
        return NotificationType.chargingCompleted;
      case 'chargingStarted':
        return NotificationType.chargingStarted;
      case 'walletLowBalance':
        return NotificationType.walletLowBalance;
      case 'lowBattery':
        return NotificationType.lowBattery;
      case 'tripReminder':
        return NotificationType.tripReminder;
      case 'nearbyCharger':
        return NotificationType.nearbyCharger;
      case 'maintenanceReminder':
        return NotificationType.maintenanceReminder;
      default:
        return NotificationType.systemInfo;
    }
  }
}
