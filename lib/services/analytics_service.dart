import '../models/wallet_statistics.dart';
import '../models/charging_session.dart';

class AnalyticsService {
  /// Calculate wallet statistics from a list of charging sessions
  WalletStatistics computeStatistics(String userId, double currentBalance, List<ChargingSession> sessions) {
    if (sessions.isEmpty) {
      return WalletStatistics(
        userId: userId,
        currentBalance: currentBalance,
        monthlySpending: 0,
        averageChargingCost: 0,
        averageCostPerKwh: 0,
        totalEnergyPurchased: 0,
        topChargingNetwork: 'N/A',
        totalChargingSessions: 0,
        estimatedFuelSavings: 0,
        co2Saved: 0,
        lastUpdated: DateTime.now(),
      );
    }

    double totalSpent = 0;
    double totalEnergy = 0;
    Map<String, int> networkCounts = {};

    final now = DateTime.now();
    double monthlySpent = 0;

    for (var session in sessions) {
      totalSpent += session.amountPaid;
      totalEnergy += session.energyUsed;
      
      networkCounts[session.network] = (networkCounts[session.network] ?? 0) + 1;

      if (session.date.year == now.year && session.date.month == now.month) {
        monthlySpent += session.amountPaid;
      }
    }

    String topNetwork = 'N/A';
    int maxCount = 0;
    networkCounts.forEach((network, count) {
      if (count > maxCount) {
        maxCount = count;
        topNetwork = network;
      }
    });

    // Mock constants for savings calculations
    const double iceCostPerKm = 8.0; // Rs 8 per km for petrol car
    const double evCostPerKm = 1.5; // Rs 1.5 per km for EV
    const double co2PerKwh = 0.5; // kg CO2 saved per kWh

    // Rough estimate of km driven based on energy
    // Assuming 7 km per kWh efficiency
    final double estimatedKmDriven = totalEnergy * 7.0;
    final double fuelSavings = estimatedKmDriven * (iceCostPerKm - evCostPerKm);
    final double co2 = totalEnergy * co2PerKwh;

    return WalletStatistics(
      userId: userId,
      currentBalance: currentBalance,
      monthlySpending: monthlySpent,
      averageChargingCost: totalSpent / sessions.length,
      averageCostPerKwh: totalEnergy > 0 ? totalSpent / totalEnergy : 0,
      totalEnergyPurchased: totalEnergy,
      topChargingNetwork: topNetwork,
      totalChargingSessions: sessions.length,
      estimatedFuelSavings: fuelSavings,
      co2Saved: co2,
      lastUpdated: DateTime.now(),
    );
  }
}
