/// ChargingTimeEstimatorService
///
/// Phase 4 Step 2 reusable service for estimating EV charging duration.
/// All results are clearly labeled as ESTIMATES.
///
/// Supports:
///   - AC charging (slow, up to ~22 kW)
///   - Fast DC charging (22–100 kW)
///   - Ultra-Fast DC charging (> 100 kW)
library;

/// Category of EV charger for estimation purposes.
enum ChargerCategory {
  /// AC charging (home/destination charger, up to ~22 kW).
  ac,

  /// DC fast charging (22–99 kW).
  fastDC,

  /// Ultra-fast DC charging (100 kW+).
  ultraFastDC,
}

/// Result from [ChargingTimeEstimatorService.estimate].
class ChargingTimeEstimate {
  /// Estimated charging duration in minutes (not exact).
  final double estimatedMinutes;

  /// Energy delivered in kWh (accounting for efficiency losses).
  final double energyDeliveredKWh;

  /// Charger category used for this estimate.
  final ChargerCategory chargerCategory;

  /// Effective charging power used in kW (min of charger max and vehicle max).
  final double effectivePowerKW;

  /// Charging efficiency applied (default 90%).
  final double chargingEfficiency;

  const ChargingTimeEstimate({
    required this.estimatedMinutes,
    required this.energyDeliveredKWh,
    required this.chargerCategory,
    required this.effectivePowerKW,
    required this.chargingEfficiency,
  });

  /// Rounded minutes.
  int get estimatedMinutesInt => estimatedMinutes.ceil();

  /// Human-friendly duration string: "45 min" or "1h 20 min".
  String get formattedDuration {
    final mins = estimatedMinutesInt;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    if (rem == 0) return '${hrs}h';
    return '${hrs}h ${rem}m';
  }

  /// Category label for display.
  String get categoryLabel {
    switch (chargerCategory) {
      case ChargerCategory.ac:
        return 'AC Charging';
      case ChargerCategory.fastDC:
        return 'Fast DC';
      case ChargerCategory.ultraFastDC:
        return 'Ultra-Fast DC';
    }
  }

  @override
  String toString() =>
      'ChargingTimeEstimate($formattedDuration, ${effectivePowerKW}kW, '
      '$categoryLabel, efficiency: ${(chargingEfficiency * 100).toStringAsFixed(0)}%)';
}

class ChargingTimeEstimatorService {
  /// Default charging efficiency (energy stored vs energy from charger).
  static const double defaultChargingEfficiency = 0.90;

  const ChargingTimeEstimatorService();

  /// Estimates charging time from [fromBatteryPct] to [toBatteryPct].
  ///
  /// [fromBatteryPct] — Starting battery percentage (0–100).
  /// [toBatteryPct] — Target battery percentage (0–100). Must be > [fromBatteryPct].
  /// [batteryCapacityKWh] — Usable battery capacity in kWh.
  /// [chargerPowerKW] — Charger's maximum output power in kW.
  /// [vehicleMaxChargingKW] — Vehicle's maximum accepted charging power in kW.
  /// [chargingEfficiency] — Fraction of charger energy stored in battery (default 0.90).
  ///
  /// Returns a [ChargingTimeEstimate] with duration and metadata.
  ChargingTimeEstimate estimate({
    required double fromBatteryPct,
    required double toBatteryPct,
    required double batteryCapacityKWh,
    required double chargerPowerKW,
    required double vehicleMaxChargingKW,
    double chargingEfficiency = defaultChargingEfficiency,
  }) {
    // Clamp inputs
    final from = fromBatteryPct.clamp(0.0, 100.0);
    final to = toBatteryPct.clamp(0.0, 100.0);

    if (to <= from) {
      return ChargingTimeEstimate(
        estimatedMinutes: 0.0,
        energyDeliveredKWh: 0.0,
        chargerCategory: _categorize(chargerPowerKW),
        effectivePowerKW: 0.0,
        chargingEfficiency: chargingEfficiency,
      );
    }

    // Energy needed (kWh) = battery capacity × (target% − from%) / 100
    final energyNeededKWh = batteryCapacityKWh * (to - from) / 100.0;

    // Account for charging efficiency: more energy drawn from charger than stored
    final energyFromChargerKWh = energyNeededKWh / chargingEfficiency;

    // Effective charging power = min of charger power and vehicle's max accepted
    final effectivePower = chargerPowerKW.clamp(0.0, vehicleMaxChargingKW);

    // Above 80% SOC, charging slows (taper). Apply correction factor:
    // If charging past 80%, average speed is roughly 70% of peak above that level.
    double adjustedTimeHours;
    if (to > 80.0 && from < 80.0) {
      // Split into two segments: from→80% at full power, 80%→to% at 70% power
      final energyTo80Kwh = batteryCapacityKWh * (80.0 - from) / 100.0;
      final energyAbove80Kwh = batteryCapacityKWh * (to - 80.0) / 100.0;
      final timeSegment1 = (energyTo80Kwh / chargingEfficiency) / effectivePower;
      final taperPower = effectivePower * 0.70;
      final timeSegment2 = (energyAbove80Kwh / chargingEfficiency) /
          (taperPower > 0 ? taperPower : effectivePower);
      adjustedTimeHours = timeSegment1 + timeSegment2;
    } else if (from >= 80.0) {
      // Already above 80%, fully tapered
      final taperPower = effectivePower * 0.70;
      adjustedTimeHours = energyFromChargerKWh / (taperPower > 0 ? taperPower : effectivePower);
    } else {
      // All charging below 80% — no taper
      adjustedTimeHours =
          effectivePower > 0 ? energyFromChargerKWh / effectivePower : 0.0;
    }

    final estimatedMinutes = adjustedTimeHours * 60.0;

    return ChargingTimeEstimate(
      estimatedMinutes: estimatedMinutes.clamp(0.0, 1440.0),
      energyDeliveredKWh: energyNeededKWh,
      chargerCategory: _categorize(effectivePower),
      effectivePowerKW: effectivePower,
      chargingEfficiency: chargingEfficiency,
    );
  }

  /// Categorizes a charger by its power output.
  ChargerCategory _categorize(double powerKW) {
    if (powerKW >= 100.0) return ChargerCategory.ultraFastDC;
    if (powerKW >= 22.0) return ChargerCategory.fastDC;
    return ChargerCategory.ac;
  }

  /// Parses power from a string like "50kW", "150 kW", "7.2kW".
  static double parsePowerKW(String powerStr) {
    final numStr = powerStr.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(numStr) ?? 0.0;
  }
}
