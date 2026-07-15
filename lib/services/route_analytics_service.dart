import '../models/route_analytics_model.dart';
import '../models/trip_plan_model.dart';

class RouteAnalyticsService {

  Future<RouteAnalyticsModel> analyzeCompletedTrip(TripPlanModel trip, double actualEnergyKwhUsed) async {
    // Simulate complex analysis
    await Future.delayed(const Duration(milliseconds: 600));

    // Calculate ICE cost equivalent (Assumes ~15km/l for ICE, ₹100/l petrol)
    // Distance roughly 120km (from our simulated DirectionsService)
    const distanceKm = 120.0;
    const iceLitersNeeded = distanceKm / 15.0;
    const iceCost = iceLitersNeeded * 100.0;
    
    // EV cost (Assumes ₹15/kWh fast charging average)
    final evCost = actualEnergyKwhUsed * 15.0;
    
    final savings = iceCost - evCost;
    
    // CO2 Savings (Assumes ICE produces ~2.3kg CO2 per liter of petrol)
    final co2Saved = iceLitersNeeded * 2.3;

    return RouteAnalyticsModel(
      id: 'ra_${trip.id}',
      tripId: trip.id,
      userId: trip.userId,
      predictedEnergyKwh: 20.0, // Simulated prediction
      actualEnergyKwh: actualEnergyKwhUsed,
      costSavingsInr: savings,
      averageSpeedKmh: 45.0, // Simulated
      co2SavedKg: co2Saved,
      completedAt: DateTime.now(),
    );
  }
}
