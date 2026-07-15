import '../models/health_model.dart';
import '../models/charging_session_model.dart';

class HealthService {
  
  /// Phase 5 Module 7: Calculates the impact of a charging session on battery health
  HealthModel calculateDegradationImpact(HealthModel currentHealth, ChargingSessionModel session) {
    // Basic heuristics: fast charging to 100% or high temps degrades battery slightly faster
    
    double degradationPenalty = 0.0;
    
    // Penalize if temperature exceeded 40°C during charge
    if (session.temperature > 40.0) {
      degradationPenalty += 0.05;
    }
    
    // Penalize if charging above 80% frequently
    if (session.batteryPercentage > 80.0) {
      degradationPenalty += 0.01;
    }
    
    // Cycle count increases roughly by the percentage charged (e.g. 50% charge = 0.5 cycles)
    final double addedCycles = (session.batteryPercentage - 20.0).clamp(0.0, 100.0) / 100.0;
    final int newCycleCount = currentHealth.cycleCount + (addedCycles > 0.5 ? 1 : 0);
    
    final newSoh = (currentHealth.stateOfHealth - degradationPenalty).clamp(0.0, 100.0);
    
    return currentHealth.copyWith(
      stateOfHealth: newSoh,
      cycleCount: newCycleCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Generate personalized recommendations based on health
  List<String> getHealthRecommendations(HealthModel health) {
    List<String> recommendations = [];
    
    if (health.stateOfHealth < 90.0) {
      recommendations.add("Your battery health is dropping. Try limiting fast charges (DC) and use slow AC charging when possible.");
    }
    if (health.chargingBehaviorScore < 70) {
      recommendations.add("Try keeping your battery between 20% and 80% for daily commutes to improve your behavior score.");
    }
    if (recommendations.isEmpty) {
      recommendations.add("Your battery is in excellent condition. Keep up the good charging habits!");
    }
    
    return recommendations;
  }
}

extension HealthModelCopy on HealthModel {
  HealthModel copyWith({
    String? vehicleId,
    String? userId,
    double? stateOfHealth,
    int? cycleCount,
    double? averageChargingEfficiency,
    int? estimatedLifespanMonths,
    double? monthlyDegradationRate,
    int? chargingBehaviorScore,
    double? drivingEfficiency,
    DateTime? lastUpdated,
  }) {
    return HealthModel(
      vehicleId: vehicleId ?? this.vehicleId,
      userId: userId ?? this.userId,
      stateOfHealth: stateOfHealth ?? this.stateOfHealth,
      cycleCount: cycleCount ?? this.cycleCount,
      averageChargingEfficiency: averageChargingEfficiency ?? this.averageChargingEfficiency,
      estimatedLifespanMonths: estimatedLifespanMonths ?? this.estimatedLifespanMonths,
      monthlyDegradationRate: monthlyDegradationRate ?? this.monthlyDegradationRate,
      chargingBehaviorScore: chargingBehaviorScore ?? this.chargingBehaviorScore,
      drivingEfficiency: drivingEfficiency ?? this.drivingEfficiency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
