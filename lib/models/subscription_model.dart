import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionTier { free, silver, gold, platinum }

class SubscriptionModel {
  final String userId;
  final SubscriptionTier tier;
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final double discountMultiplier; // e.g., 0.9 for 10% off charging
  final int freeChargingCredits; // kWh per month

  const SubscriptionModel({
    required this.userId,
    this.tier = SubscriptionTier.free,
    required this.startDate,
    required this.endDate,
    this.autoRenew = false,
    this.discountMultiplier = 1.0,
    this.freeChargingCredits = 0,
  });

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      userId: data['userId'] ?? doc.id,
      tier: _tierFromString(data['tier']),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 30)),
      autoRenew: data['autoRenew'] ?? false,
      discountMultiplier: (data['discountMultiplier'] ?? 1.0).toDouble(),
      freeChargingCredits: data['freeChargingCredits'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tier': tier.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'autoRenew': autoRenew,
      'discountMultiplier': discountMultiplier,
      'freeChargingCredits': freeChargingCredits,
    };
  }

  static SubscriptionTier _tierFromString(String? str) {
    switch (str) {
      case 'silver':
        return SubscriptionTier.silver;
      case 'gold':
        return SubscriptionTier.gold;
      case 'platinum':
        return SubscriptionTier.platinum;
      default:
        return SubscriptionTier.free;
    }
  }
}
