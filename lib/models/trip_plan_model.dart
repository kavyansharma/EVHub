import 'package:cloud_firestore/cloud_firestore.dart';

class TripPlanModel {
  final String id;
  final String userId;
  final String destination;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  
  // Advanced Trip Fields
  final double estimatedBatteryPrediction; // e.g. end trip at 15%
  final String weatherImpact; // e.g. "Heavy Rain: -5% range"
  final String elevationImpact; // e.g. "Uphill: -10% range"
  final String trafficImpact; 
  final bool returnTripIncluded;
  final List<String> recommendedChargingStops; // Station IDs
  final DateTime plannedDate;

  const TripPlanModel({
    required this.id,
    required this.userId,
    required this.destination,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.estimatedBatteryPrediction = 0.0,
    this.weatherImpact = 'Clear',
    this.elevationImpact = 'Flat',
    this.trafficImpact = 'Normal',
    this.returnTripIncluded = false,
    this.recommendedChargingStops = const [],
    required this.plannedDate,
  });

  factory TripPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripPlanModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      destination: data['destination'] ?? '',
      startLat: (data['startLat'] ?? 0.0).toDouble(),
      startLng: (data['startLng'] ?? 0.0).toDouble(),
      endLat: (data['endLat'] ?? 0.0).toDouble(),
      endLng: (data['endLng'] ?? 0.0).toDouble(),
      estimatedBatteryPrediction: (data['estimatedBatteryPrediction'] ?? 0.0).toDouble(),
      weatherImpact: data['weatherImpact'] ?? '',
      elevationImpact: data['elevationImpact'] ?? '',
      trafficImpact: data['trafficImpact'] ?? '',
      returnTripIncluded: data['returnTripIncluded'] ?? false,
      recommendedChargingStops: List<String>.from(data['recommendedChargingStops'] ?? []),
      plannedDate: (data['plannedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'destination': destination,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'estimatedBatteryPrediction': estimatedBatteryPrediction,
      'weatherImpact': weatherImpact,
      'elevationImpact': elevationImpact,
      'trafficImpact': trafficImpact,
      'returnTripIncluded': returnTripIncluded,
      'recommendedChargingStops': recommendedChargingStops,
      'plannedDate': Timestamp.fromDate(plannedDate),
    };
  }
}
