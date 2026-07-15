import 'package:cloud_firestore/cloud_firestore.dart';

class WalletStatistics {
  final String userId;
  final double currentBalance;
  final double monthlySpending;
  final double averageChargingCost;
  final double averageCostPerKwh;
  final double totalEnergyPurchased; // in kWh
  final String topChargingNetwork;
  final int totalChargingSessions;
  final double estimatedFuelSavings; // in Rs
  final double co2Saved; // in kg
  final DateTime lastUpdated;

  const WalletStatistics({
    required this.userId,
    required this.currentBalance,
    required this.monthlySpending,
    required this.averageChargingCost,
    required this.averageCostPerKwh,
    required this.totalEnergyPurchased,
    required this.topChargingNetwork,
    required this.totalChargingSessions,
    required this.estimatedFuelSavings,
    required this.co2Saved,
    required this.lastUpdated,
  });

  factory WalletStatistics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletStatistics(
      userId: doc.id, // Using userId as document ID
      currentBalance: (data['currentBalance'] ?? 0.0).toDouble(),
      monthlySpending: (data['monthlySpending'] ?? 0.0).toDouble(),
      averageChargingCost: (data['averageChargingCost'] ?? 0.0).toDouble(),
      averageCostPerKwh: (data['averageCostPerKwh'] ?? 0.0).toDouble(),
      totalEnergyPurchased: (data['totalEnergyPurchased'] ?? 0.0).toDouble(),
      topChargingNetwork: data['topChargingNetwork'] ?? 'N/A',
      totalChargingSessions: data['totalChargingSessions'] ?? 0,
      estimatedFuelSavings: (data['estimatedFuelSavings'] ?? 0.0).toDouble(),
      co2Saved: (data['co2Saved'] ?? 0.0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentBalance': currentBalance,
      'monthlySpending': monthlySpending,
      'averageChargingCost': averageChargingCost,
      'averageCostPerKwh': averageCostPerKwh,
      'totalEnergyPurchased': totalEnergyPurchased,
      'topChargingNetwork': topChargingNetwork,
      'totalChargingSessions': totalChargingSessions,
      'estimatedFuelSavings': estimatedFuelSavings,
      'co2Saved': co2Saved,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
