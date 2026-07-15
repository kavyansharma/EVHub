import '../models/battery_health.dart';

class BatteryHealthService {
  /// Fetches battery health (mocked)
  Future<BatteryHealth> getBatteryHealth(String vehicleId, String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    return BatteryHealth(
      id: 'health_$vehicleId',
      vehicleId: vehicleId,
      userId: userId,
      healthPercentage: 96.5,
      chargingCycles: 120,
      fastChargingUsage: 45,
      averageBatteryTemperature: 28.5,
      estimatedDegradation: 3.5,
      estimatedRemainingLife: 108, // 9 years
      lastUpdated: DateTime.now(),
      chargingRecommendations: [
        'Keep battery between 20% and 80% for daily use.',
        'Limit DC fast charging to long trips.',
        'Avoid parking in direct sunlight on hot days.',
      ],
    );
  }
}
