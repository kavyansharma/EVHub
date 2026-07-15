import 'package:cloud_firestore/cloud_firestore.dart';

class RouteAnalyticsModel {
  final String id;
  final String tripId;
  final String userId;
  final double predictedEnergyKwh;
  final double actualEnergyKwh;
  final double costSavingsInr; // vs ICE vehicle
  final double averageSpeedKmh;
  final double co2SavedKg;
  final DateTime completedAt;

  const RouteAnalyticsModel({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.predictedEnergyKwh,
    required this.actualEnergyKwh,
    required this.costSavingsInr,
    required this.averageSpeedKmh,
    required this.co2SavedKg,
    required this.completedAt,
  });

  factory RouteAnalyticsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RouteAnalyticsModel(
      id: doc.id,
      tripId: data['tripId'] ?? '',
      userId: data['userId'] ?? '',
      predictedEnergyKwh: (data['predictedEnergyKwh'] ?? 0.0).toDouble(),
      actualEnergyKwh: (data['actualEnergyKwh'] ?? 0.0).toDouble(),
      costSavingsInr: (data['costSavingsInr'] ?? 0.0).toDouble(),
      averageSpeedKmh: (data['averageSpeedKmh'] ?? 0.0).toDouble(),
      co2SavedKg: (data['co2SavedKg'] ?? 0.0).toDouble(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'userId': userId,
      'predictedEnergyKwh': predictedEnergyKwh,
      'actualEnergyKwh': actualEnergyKwh,
      'costSavingsInr': costSavingsInr,
      'averageSpeedKmh': averageSpeedKmh,
      'co2SavedKg': co2SavedKg,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }
}
