import '../models/trip_analysis.dart';
import '../models/vehicle_model.dart';

class TripPlannerService {
  /// Generate a trip analysis summary.
  /// Uses mocked logic that can be later replaced with Google Maps API and live charger endpoints.
  TripAnalysis analyzeTrip({
    required VehicleModel vehicle,
    required String origin,
    required String destination,
    required double currentBatteryPct,
  }) {
    // Mock calculations based on strings
    double estimatedDistance = 350.0; // km
    if (destination.toLowerCase().contains('mumbai')) estimatedDistance = 150.0;
    if (destination.toLowerCase().contains('delhi')) estimatedDistance = 1400.0;
    
    // Calculate if stops are needed
    final double rangeAvailable = vehicle.realRange * (currentBatteryPct / 100);
    int stops = 0;
    double remainingDistance = estimatedDistance - rangeAvailable;
    
    while (remainingDistance > 0) {
      stops++;
      // Assuming charging to 80% at each stop
      remainingDistance -= (vehicle.realRange * 0.8);
    }

    // Mock calculations
    final Duration driveTime = Duration(minutes: (estimatedDistance / 60 * 60).round());
    final Duration chargeTime = Duration(minutes: stops * 45); // 45 mins per stop
    
    // Energy cost
    final double energyConsumption = estimatedDistance / 7.0; // assuming 7km/kWh
    final double chargingCost = stops > 0 ? (stops * 30 * 20.0) : 0; // rough cost estimate

    int batteryOnArrival = 15; // default buffer
    if (stops == 0) {
      batteryOnArrival = (((rangeAvailable - estimatedDistance) / vehicle.realRange) * 100).round();
      if (batteryOnArrival < 0) batteryOnArrival = 5;
    }

    return TripAnalysis(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicle.id,
      origin: origin,
      destination: destination,
      batteryOnArrival: batteryOnArrival,
      recommendedChargingStops: stops,
      chargingDuration: chargeTime,
      chargingCost: chargingCost,
      tripDistance: estimatedDistance,
      tripTime: driveTime + chargeTime,
      energyConsumption: energyConsumption,
      alternativeRoutes: 2,
      compatibleChargers: stops * 3, // Mock number of compatible chargers on route
    );
  }
}
