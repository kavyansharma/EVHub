class TripAnalysis {
  final String id;
  final String vehicleId;
  final String origin;
  final String destination;
  final int batteryOnArrival; // percentage
  final int recommendedChargingStops;
  final Duration chargingDuration;
  final double chargingCost; // in Rs
  final double tripDistance; // in km
  final Duration tripTime;
  final double energyConsumption; // in kWh
  final int alternativeRoutes;
  final int compatibleChargers;

  const TripAnalysis({
    required this.id,
    required this.vehicleId,
    required this.origin,
    required this.destination,
    required this.batteryOnArrival,
    required this.recommendedChargingStops,
    required this.chargingDuration,
    required this.chargingCost,
    required this.tripDistance,
    required this.tripTime,
    required this.energyConsumption,
    required this.alternativeRoutes,
    required this.compatibleChargers,
  });

  factory TripAnalysis.fromMap(Map<String, dynamic> map) {
    return TripAnalysis(
      id: map['id'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      batteryOnArrival: map['batteryOnArrival'] ?? 0,
      recommendedChargingStops: map['recommendedChargingStops'] ?? 0,
      chargingDuration: Duration(minutes: map['chargingDurationMinutes'] ?? 0),
      chargingCost: (map['chargingCost'] ?? 0.0).toDouble(),
      tripDistance: (map['tripDistance'] ?? 0.0).toDouble(),
      tripTime: Duration(minutes: map['tripTimeMinutes'] ?? 0),
      energyConsumption: (map['energyConsumption'] ?? 0.0).toDouble(),
      alternativeRoutes: map['alternativeRoutes'] ?? 0,
      compatibleChargers: map['compatibleChargers'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'origin': origin,
      'destination': destination,
      'batteryOnArrival': batteryOnArrival,
      'recommendedChargingStops': recommendedChargingStops,
      'chargingDurationMinutes': chargingDuration.inMinutes,
      'chargingCost': chargingCost,
      'tripDistance': tripDistance,
      'tripTimeMinutes': tripTime.inMinutes,
      'energyConsumption': energyConsumption,
      'alternativeRoutes': alternativeRoutes,
      'compatibleChargers': compatibleChargers,
    };
  }
}
