import '../models/trip_plan_model.dart';

class DirectionsService {
  // TODO: Integrate Google Directions API

  Future<TripPlanModel> calculateAdvancedTrip({
    required TripPlanModel basePlan,
    required double currentBatteryPct,
    required double vehicleEfficiency, // km/kWh
    required double batteryCapacityKw,
  }) async {
    // Simulated calculation for directions & environmental factors
    await Future.delayed(const Duration(milliseconds: 800));

    // Base distance
    const double distanceKm = 120.0; // Simulated distance

    // Environmental impacts
    double impactMultiplier = 1.0;
    
    if (basePlan.weatherImpact.contains('Rain') || basePlan.weatherImpact.contains('Cold')) {
      impactMultiplier *= 1.15; // 15% more consumption
    }
    
    if (basePlan.elevationImpact.contains('Uphill')) {
      impactMultiplier *= 1.25; // 25% more consumption
    }
    
    if (basePlan.trafficImpact.contains('Heavy')) {
      impactMultiplier *= 1.10; // 10% more consumption in heavy stop-go traffic
    }

    final adjustedEfficiency = vehicleEfficiency / impactMultiplier;
    final kwhNeeded = distanceKm / adjustedEfficiency;
    final batteryPctNeeded = (kwhNeeded / batteryCapacityKw) * 100;
    
    double estimatedEndBattery = currentBatteryPct - batteryPctNeeded;
    List<String> stops = [];

    // If battery drops below 15%, recommend a stop
    if (estimatedEndBattery < 15.0) {
      stops.add('st_1'); // Add a simulated station ID on route
      estimatedEndBattery += 40.0; // Assume they charge 40%
    }

    return TripPlanModel(
      id: basePlan.id,
      userId: basePlan.userId,
      destination: basePlan.destination,
      startLat: basePlan.startLat,
      startLng: basePlan.startLng,
      endLat: basePlan.endLat,
      endLng: basePlan.endLng,
      estimatedBatteryPrediction: estimatedEndBattery.clamp(0.0, 100.0),
      weatherImpact: basePlan.weatherImpact,
      elevationImpact: basePlan.elevationImpact,
      trafficImpact: basePlan.trafficImpact,
      returnTripIncluded: basePlan.returnTripIncluded,
      recommendedChargingStops: stops,
      plannedDate: basePlan.plannedDate,
    );
  }
}
