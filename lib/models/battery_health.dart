import 'package:cloud_firestore/cloud_firestore.dart';

class BatteryHealth {
  final String id;
  final String vehicleId;
  final String userId;
  final double healthPercentage;
  final int chargingCycles;
  final int fastChargingUsage; // number of times DC fast charged
  final double averageBatteryTemperature; // in Celsius
  final double estimatedDegradation; // percentage degraded
  final int estimatedRemainingLife; // in months or years, let's say months
  final DateTime lastUpdated;
  final List<String> chargingRecommendations;

  const BatteryHealth({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.healthPercentage,
    required this.chargingCycles,
    required this.fastChargingUsage,
    required this.averageBatteryTemperature,
    required this.estimatedDegradation,
    required this.estimatedRemainingLife,
    required this.lastUpdated,
    required this.chargingRecommendations,
  });

  factory BatteryHealth.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BatteryHealth(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      userId: data['userId'] ?? '',
      healthPercentage: (data['healthPercentage'] ?? 100.0).toDouble(),
      chargingCycles: data['chargingCycles'] ?? 0,
      fastChargingUsage: data['fastChargingUsage'] ?? 0,
      averageBatteryTemperature: (data['averageBatteryTemperature'] ?? 25.0).toDouble(),
      estimatedDegradation: (data['estimatedDegradation'] ?? 0.0).toDouble(),
      estimatedRemainingLife: data['estimatedRemainingLife'] ?? 120, // 10 years default
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      chargingRecommendations: List<String>.from(data['chargingRecommendations'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'userId': userId,
      'healthPercentage': healthPercentage,
      'chargingCycles': chargingCycles,
      'fastChargingUsage': fastChargingUsage,
      'averageBatteryTemperature': averageBatteryTemperature,
      'estimatedDegradation': estimatedDegradation,
      'estimatedRemainingLife': estimatedRemainingLife,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'chargingRecommendations': chargingRecommendations,
    };
  }
}
