import 'dart:math' as math;

/// Results returned by [SmartChargingCalculator]
class SmartChargingResult {
  final double energyRequiredKwh; // Net kWh added to battery
  final double grossEnergyFromGridKwh; // Gross kWh drawn from grid factoring in efficiency
  final double effectivePowerKw; // Minimum of charger power and vehicle max power
  final int estimatedTimeMinutes; // Estimated charging time in minutes
  final double estimatedCost; // Estimated cost in INR
  final double estimatedRangeAddedKm; // Estimated range added in km
  final int efficiencyPercentage; // Efficiency % (90%, 92%, or 94%)

  const SmartChargingResult({
    required this.energyRequiredKwh,
    required this.grossEnergyFromGridKwh,
    required this.effectivePowerKw,
    required this.estimatedTimeMinutes,
    required this.estimatedCost,
    required this.estimatedRangeAddedKm,
    required this.efficiencyPercentage,
  });

  String get formattedTime {
    if (estimatedTimeMinutes < 60) {
      return '$estimatedTimeMinutes min';
    }
    final hours = estimatedTimeMinutes ~/ 60;
    final mins = estimatedTimeMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

/// SmartChargingCalculator
///
/// Production-grade utility to compute EV charging energy, time, cost,
/// and range additions based on vehicle specifications, battery levels,
/// charger power ratings, and charging efficiency curves.
class SmartChargingCalculator {
  /// Efficiency rate assumptions:
  /// • AC Charging: 90% (0.90)
  /// • DC Fast Charging: 92% (0.92)
  /// • Ultra Fast DC Charging: 94% (0.94)
  static double getEfficiencyFactor(String powerType) {
    final type = powerType.toLowerCase().trim();
    if (type.contains('ac')) return 0.90;
    if (type.contains('ultra')) return 0.94;
    return 0.92; // Default Fast DC
  }

  /// Calculates smart charging metrics based on battery levels and ratings.
  static SmartChargingResult calculate({
    required double currentBatteryPct,
    required double targetBatteryPct,
    required double chargerPowerKw,
    required double vehicleMaxPowerKw,
    required double batteryCapacityKwh,
    required double pricePerKwh,
    required String powerType,
    double vehicleEfficiencyWhPerKm = 150.0, // Default EV efficiency
  }) {
    // 1. Sanitize battery percentages
    final double startPct = currentBatteryPct.clamp(0.0, 100.0);
    final double endPct = targetBatteryPct.clamp(startPct, 100.0);
    final double pctDelta = (endPct - startPct) / 100.0;

    // 2. Calculate net energy required in kWh
    final double capacity = batteryCapacityKwh > 0 ? batteryCapacityKwh : 50.0;
    final double energyRequiredKwh = capacity * pctDelta;

    // 3. Efficiency factor & gross grid draw
    final double efficiencyFactor = getEfficiencyFactor(powerType);
    final double grossEnergyFromGridKwh = energyRequiredKwh / efficiencyFactor;

    // 4. Effective charging power = min(charger power, vehicle max acceptance)
    final double effectivePowerKw = math.min(
      chargerPowerKw > 0 ? chargerPowerKw : 50.0,
      vehicleMaxPowerKw > 0 ? vehicleMaxPowerKw : 150.0,
    );

    // 5. Estimated time in minutes
    final double timeHours = effectivePowerKw > 0 ? (grossEnergyFromGridKwh / effectivePowerKw) : 0;
    final int estimatedTimeMinutes = (timeHours * 60).round();

    // 6. Estimated cost
    final double estimatedCost = grossEnergyFromGridKwh * pricePerKwh;

    // 7. Estimated range added (in km)
    final double efficiencyWhPerKm = vehicleEfficiencyWhPerKm > 0 ? vehicleEfficiencyWhPerKm : 150.0;
    final double estimatedRangeAddedKm = (energyRequiredKwh * 1000.0) / efficiencyWhPerKm;

    return SmartChargingResult(
      energyRequiredKwh: energyRequiredKwh,
      grossEnergyFromGridKwh: grossEnergyFromGridKwh,
      effectivePowerKw: effectivePowerKw,
      estimatedTimeMinutes: estimatedTimeMinutes,
      estimatedCost: estimatedCost,
      estimatedRangeAddedKm: estimatedRangeAddedKm,
      efficiencyPercentage: (efficiencyFactor * 100).round(),
    );
  }

  /// Parses price string like "₹21/kWh" or "21.5" into numeric double.
  static double parsePrice(String? priceString) {
    if (priceString == null || priceString.trim().isEmpty) return 21.0;
    final match = RegExp(r'[0-9.]+').firstMatch(priceString);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 21.0;
    }
    return 21.0;
  }
}
