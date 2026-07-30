import '../models/vehicle_model.dart';

enum ChargingRequirementStatus {
  rangeSufficient,
  chargingRequired,
  noRouteCalculated,
  noVehicleSelected,
}

class TripEnergyAnalysisResult {
  final double availableEnergyKwh;
  final double estimatedRangeKm;
  final double tripEnergyRequiredKwh;
  final double requiredRangeWithBufferKm;
  final ChargingRequirementStatus status;
  final String statusMessage;
  final String statusTitle;

  const TripEnergyAnalysisResult({
    required this.availableEnergyKwh,
    required this.estimatedRangeKm,
    required this.tripEnergyRequiredKwh,
    required this.requiredRangeWithBufferKm,
    required this.status,
    required this.statusMessage,
    required this.statusTitle,
  });
}

class TripEnergyCalculator {
  /// 1. Available Energy (kWh) = Usable Battery Capacity (kWh) * (Battery % / 100)
  static double calculateAvailableEnergy({
    required double batteryCapacityKwh,
    required double batteryPct,
  }) {
    final cleanPct = batteryPct.clamp(0.0, 100.0);
    return batteryCapacityKwh * (cleanPct / 100.0);
  }

  /// 2. Estimated Remaining Range (km) = Available Energy (kWh) / Efficiency (kWh/km)
  /// Note: efficiencyWhPerKm is converted to kWh/km via / 1000.0.
  static double calculateEstimatedRange({
    required double availableEnergyKwh,
    required double efficiencyWhPerKm,
  }) {
    if (efficiencyWhPerKm <= 0) return 0.0;
    final efficiencyKwhPerKm = efficiencyWhPerKm / 1000.0;
    return availableEnergyKwh / efficiencyKwhPerKm;
  }

  /// 3. Estimated Trip Energy Required (kWh) = Trip Distance (km) * Efficiency (kWh/km)
  static double calculateTripEnergy({
    required double tripDistanceKm,
    required double efficiencyWhPerKm,
  }) {
    if (tripDistanceKm <= 0 || efficiencyWhPerKm <= 0) return 0.0;
    final efficiencyKwhPerKm = efficiencyWhPerKm / 1000.0;
    return tripDistanceKm * efficiencyKwhPerKm;
  }

  /// 4. Required Planning Range with Safety Buffer (km) = Trip Distance * (1 + Safety Buffer % / 100)
  static double calculateRequiredRangeWithBuffer({
    required double tripDistanceKm,
    required double safetyBufferPct,
  }) {
    if (tripDistanceKm <= 0) return 0.0;
    final cleanBufferPct = safetyBufferPct < 0 ? 0.0 : safetyBufferPct;
    return tripDistanceKm * (1.0 + (cleanBufferPct / 100.0));
  }

  /// 5. Full Trip Energy Evaluation
  static TripEnergyAnalysisResult analyze({
    required VehicleModel? vehicle,
    required double batteryPct,
    required double? tripDistanceKm,
    double safetyBufferPct = 15.0,
  }) {
    if (vehicle == null) {
      return const TripEnergyAnalysisResult(
        availableEnergyKwh: 0.0,
        estimatedRangeKm: 0.0,
        tripEnergyRequiredKwh: 0.0,
        requiredRangeWithBufferKm: 0.0,
        status: ChargingRequirementStatus.noVehicleSelected,
        statusTitle: 'Select Your EV',
        statusMessage: 'Select an EV vehicle to calculate battery range and trip energy.',
      );
    }

    final double availableEnergy = calculateAvailableEnergy(
      batteryCapacityKwh: vehicle.usableBatteryCapacity,
      batteryPct: batteryPct,
    );

    final double estimatedRange = calculateEstimatedRange(
      availableEnergyKwh: availableEnergy,
      efficiencyWhPerKm: vehicle.averageEfficiency,
    );

    if (tripDistanceKm == null || tripDistanceKm <= 0.0) {
      return TripEnergyAnalysisResult(
        availableEnergyKwh: availableEnergy,
        estimatedRangeKm: estimatedRange,
        tripEnergyRequiredKwh: 0.0,
        requiredRangeWithBufferKm: 0.0,
        status: ChargingRequirementStatus.noRouteCalculated,
        statusTitle: 'Plan Your Trip',
        statusMessage: 'Enter origin and destination to calculate trip energy requirements.',
      );
    }

    final double tripEnergyRequired = calculateTripEnergy(
      tripDistanceKm: tripDistanceKm,
      efficiencyWhPerKm: vehicle.averageEfficiency,
    );

    final double requiredRangeWithBuffer = calculateRequiredRangeWithBuffer(
      tripDistanceKm: tripDistanceKm,
      safetyBufferPct: safetyBufferPct,
    );

    final bool isRangeSufficient = estimatedRange >= requiredRangeWithBuffer;

    if (isRangeSufficient) {
      return TripEnergyAnalysisResult(
        availableEnergyKwh: availableEnergy,
        estimatedRangeKm: estimatedRange,
        tripEnergyRequiredKwh: tripEnergyRequired,
        requiredRangeWithBufferKm: requiredRangeWithBuffer,
        status: ChargingRequirementStatus.rangeSufficient,
        statusTitle: 'Range Check',
        statusMessage: 'Your estimated range is sufficient for this trip.',
      );
    } else {
      return TripEnergyAnalysisResult(
        availableEnergyKwh: availableEnergy,
        estimatedRangeKm: estimatedRange,
        tripEnergyRequiredKwh: tripEnergyRequired,
        requiredRangeWithBufferKm: requiredRangeWithBuffer,
        status: ChargingRequirementStatus.chargingRequired,
        statusTitle: 'Charging Recommended',
        statusMessage: 'You may need to charge during this trip.',
      );
    }
  }
}
