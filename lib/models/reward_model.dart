import 'package:cloud_firestore/cloud_firestore.dart';

enum RewardAction { dailyLogin, charging, referral, achievement, redemption }

class RewardModel {
  final String id;
  final String userId;
  final int points;
  final String title;
  final String description;
  final RewardAction action;
  final DateTime timestamp;

  const RewardModel({
    required this.id,
    required this.userId,
    required this.points,
    required this.title,
    required this.description,
    required this.action,
    required this.timestamp,
  });

  factory RewardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RewardModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      points: data['points'] ?? 0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      action: _actionFromString(data['action']),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'points': points,
      'title': title,
      'description': description,
      'action': action.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  static RewardAction _actionFromString(String? actionStr) {
    switch (actionStr) {
      case 'charging':
        return RewardAction.charging;
      case 'referral':
        return RewardAction.referral;
      case 'achievement':
        return RewardAction.achievement;
      case 'redemption':
        return RewardAction.redemption;
      default:
        return RewardAction.dailyLogin;
    }
  }
}
