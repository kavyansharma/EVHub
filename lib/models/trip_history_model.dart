import 'package:cloud_firestore/cloud_firestore.dart';

class TripStopModel {
  final String name;
  final double distanceFromStart;
  final double estimatedBatteryPercent;
  final double chargeTimeMinutes;

  const TripStopModel({
    required this.name,
    required this.distanceFromStart,
    required this.estimatedBatteryPercent,
    required this.chargeTimeMinutes,
  });

  factory TripStopModel.fromMap(Map<String, dynamic> data) {
    return TripStopModel(
      name: data['name'] ?? '',
      distanceFromStart: (data['distanceFromStart'] ?? 0.0).toDouble(),
      estimatedBatteryPercent: (data['estimatedBatteryPercent'] ?? 0.0).toDouble(),
      chargeTimeMinutes: (data['chargeTimeMinutes'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'distanceFromStart': distanceFromStart,
      'estimatedBatteryPercent': estimatedBatteryPercent,
      'chargeTimeMinutes': chargeTimeMinutes,
    };
  }
}

class TripHistoryModel {
  final String id;
  final String userId;
  final String origin;
  final String destination;
  final List<TripStopModel> stops;
  final double totalDistanceKm;
  final DateTime timestamp;

  const TripHistoryModel({
    required this.id,
    required this.userId,
    required this.origin,
    required this.destination,
    required this.stops,
    required this.totalDistanceKm,
    required this.timestamp,
  });

  factory TripHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStops = data['stops'] as List<dynamic>? ?? [];
    return TripHistoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      stops: rawStops
          .map((s) => TripStopModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      totalDistanceKm: (data['totalDistanceKm'] ?? 0.0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'origin': origin,
      'destination': destination,
      'stops': stops.map((s) => s.toMap()).toList(),
      'totalDistanceKm': totalDistanceKm,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
