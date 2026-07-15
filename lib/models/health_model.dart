import 'package:cloud_firestore/cloud_firestore.dart';

class HealthModel {
  final String vehicleId;
  final String userId;
  final double stateOfHealth; // e.g. 96.5 %
  final int cycleCount;
  final double averageChargingEfficiency;
  final int estimatedLifespanMonths;
  final double monthlyDegradationRate;
  final int chargingBehaviorScore; // 0-100
  final double drivingEfficiency; // km/kWh
  final DateTime lastUpdated;

  const HealthModel({
    required this.vehicleId,
    required this.userId,
    this.stateOfHealth = 100.0,
    this.cycleCount = 0,
    this.averageChargingEfficiency = 95.0,
    this.estimatedLifespanMonths = 120, // 10 years default
    this.monthlyDegradationRate = 0.1,
    this.chargingBehaviorScore = 100,
    this.drivingEfficiency = 7.5,
    required this.lastUpdated,
  });

  factory HealthModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthModel(
      vehicleId: doc.id,
      userId: data['userId'] ?? '',
      stateOfHealth: (data['stateOfHealth'] ?? 100.0).toDouble(),
      cycleCount: data['cycleCount'] ?? 0,
      averageChargingEfficiency: (data['averageChargingEfficiency'] ?? 95.0).toDouble(),
      estimatedLifespanMonths: data['estimatedLifespanMonths'] ?? 120,
      monthlyDegradationRate: (data['monthlyDegradationRate'] ?? 0.1).toDouble(),
      chargingBehaviorScore: data['chargingBehaviorScore'] ?? 100,
      drivingEfficiency: (data['drivingEfficiency'] ?? 7.5).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stateOfHealth': stateOfHealth,
      'cycleCount': cycleCount,
      'averageChargingEfficiency': averageChargingEfficiency,
      'estimatedLifespanMonths': estimatedLifespanMonths,
      'monthlyDegradationRate': monthlyDegradationRate,
      'chargingBehaviorScore': chargingBehaviorScore,
      'drivingEfficiency': drivingEfficiency,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
