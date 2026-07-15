import '../models/vehicle_model.dart';

class ChargingCalculationResult {
  final double requiredEnergyKwh;
  final double estimatedTimeHours;
  final double estimatedCost;
  final double rangeAddedKm;
  final double efficiencyLossKwh;
  final String temperatureImpact;
  final int projectedBatteryHealthScore;

  const ChargingCalculationResult({
    required this.requiredEnergyKwh,
    required this.estimatedTimeHours,
    required this.estimatedCost,
    required this.rangeAddedKm,
    required this.efficiencyLossKwh,
    required this.temperatureImpact,
    required this.projectedBatteryHealthScore,
  });
}

class ChargingCalculatorService {
  /// Calculate charging metrics based on parameters
  ChargingCalculationResult calculate({
    required VehicleModel vehicle,
    required int currentBatteryPct,
    required int targetBatteryPct,
    required double chargerSpeedKw,
    required double costPerKwh,
    double currentTemperatureC = 25.0,
  }) {
    if (targetBatteryPct <= currentBatteryPct) {
      return const ChargingCalculationResult(
        requiredEnergyKwh: 0,
        estimatedTimeHours: 0,
        estimatedCost: 0,
        rangeAddedKm: 0,
        efficiencyLossKwh: 0,
        temperatureImpact: 'N/A',
        projectedBatteryHealthScore: 100,
      );
    }

    final double pctToCharge = (targetBatteryPct - currentBatteryPct) / 100.0;
    
    // Base energy required
    final double rawEnergyKwh = vehicle.batteryCapacity * pctToCharge;

    // Efficiency loss (typically 10-15% for AC, 5-10% for DC)
    final double efficiencyFactor = chargerSpeedKw > 22.0 ? 0.90 : 0.85; 
    final double requiredEnergyKwh = rawEnergyKwh / efficiencyFactor;
    final double efficiencyLossKwh = requiredEnergyKwh - rawEnergyKwh;

    // Time calculation
    // Cap charging speed to vehicle's max capability
    final double actualChargingSpeed = chargerSpeedKw > 22.0
        ? (chargerSpeedKw > vehicle.maxDcChargingSpeed ? vehicle.maxDcChargingSpeed : chargerSpeedKw)
        : (chargerSpeedKw > vehicle.maxAcChargingSpeed ? vehicle.maxAcChargingSpeed : chargerSpeedKw);
    
    // Tapering factor (Charging slows down past 80%)
    double timeMultiplier = 1.0;
    if (targetBatteryPct > 80) {
      timeMultiplier = 1.4; // 40% longer due to tapering
    }

    final double estimatedTimeHours = (requiredEnergyKwh / actualChargingSpeed) * timeMultiplier;
    
    // Cost calculation
    final double estimatedCost = requiredEnergyKwh * costPerKwh;

    // Range calculation
    final double rangeAddedKm = vehicle.realRange * pctToCharge;

    // Temperature Impact
    String tempImpact = 'Optimal';
    if (currentTemperatureC < 10) {
      tempImpact = 'Slowed (Cold Battery)';
    } else if (currentTemperatureC > 35) {
      tempImpact = 'Throttled (Hot Battery)';
    }

    return ChargingCalculationResult(
      requiredEnergyKwh: requiredEnergyKwh,
      estimatedTimeHours: estimatedTimeHours,
      estimatedCost: estimatedCost,
      rangeAddedKm: rangeAddedKm,
      efficiencyLossKwh: efficiencyLossKwh,
      temperatureImpact: tempImpact,
      projectedBatteryHealthScore: 98, // Mocked health score
    );
  }
}
