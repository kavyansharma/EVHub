/// SmartTripCalculatorService
///
/// Phase 4 Step 2 dedicated service for smart trip energy analysis.
/// Calculates: trip distance energy, battery at destination, whether
/// charging is required, and how many stops are estimated.
///
/// All values are clearly labeled as ESTIMATES.
/// Does NOT contain UI logic. Does NOT interact with Firestore directly.
library;

import '../models/ev_vehicle_model.dart';
import '../services/trip_energy_calculator.dart';

/// Configuration constants for the smart trip calculator.
class SmartTripConfig {
  /// Default safety reserve percentage (battery % to keep in reserve).
  static const double defaultSafetyReservePct = 15.0;

  /// Default charging efficiency (energy accepted vs energy delivered).
  static const double defaultChargingEfficiency = 0.90;

  /// Minimum battery percentage to arrive at any stop (safety floor).
  static const double minimumArrivalBatteryPct = 10.0;

  /// Recommended charging target percentage when a stop is planned.
  static const double defaultChargingTargetPct = 75.0;
}

/// Detailed result from [SmartTripCalculatorService.calculate].
class SmartTripCalculationResult {
  /// Trip distance in km.
  final double tripDistanceKm;

  /// Estimated energy needed for the full trip in kWh.
  final double tripEnergyRequiredKWh;

  /// Battery percentage needed (no charging) to complete with safety reserve.
  final double requiredBatteryWithReservePct;

  /// Estimated battery % remaining at destination (no intermediate charging).
  final double estimatedBatteryAtDestinationPct;

  /// Whether charging is required.
  final bool chargingRequired;

  /// Estimated minimum number of charging stops needed.
  final int estimatedChargingStopsNeeded;

  /// Available energy in kWh from current battery %.
  final double availableEnergyKWh;

  /// Estimated range the vehicle can travel from current battery in km.
  final double estimatedRangeKm;

  /// Safety reserve percentage used in this calculation.
  final double safetyReservePct;

  const SmartTripCalculationResult({
    required this.tripDistanceKm,
    required this.tripEnergyRequiredKWh,
    required this.requiredBatteryWithReservePct,
    required this.estimatedBatteryAtDestinationPct,
    required this.chargingRequired,
    required this.estimatedChargingStopsNeeded,
    required this.availableEnergyKWh,
    required this.estimatedRangeKm,
    required this.safetyReservePct,
  });

  @override
  String toString() =>
      'SmartTripCalcResult(dist: ${tripDistanceKm}km, '
      'energy: ${tripEnergyRequiredKWh}kWh, '
      'battAtDest: ${estimatedBatteryAtDestinationPct.toStringAsFixed(1)}%, '
      'chargingReq: $chargingRequired, '
      'stopsNeeded: $estimatedChargingStopsNeeded)';
}

class SmartTripCalculatorService {
  /// Default charging efficiency: 90%.
  final double chargingEfficiency;

  /// Default safety reserve: 15%.
  final double safetyReservePct;

  const SmartTripCalculatorService({
    this.chargingEfficiency = SmartTripConfig.defaultChargingEfficiency,
    this.safetyReservePct = SmartTripConfig.defaultSafetyReservePct,
  });

  /// Calculate smart trip parameters for a given vehicle, battery, and route distance.
  ///
  /// [vehicle] — The selected EV vehicle profile.
  /// [currentBatteryPct] — Current battery percentage (0–100).
  /// [tripDistanceKm] — Total route distance in km.
  /// [safetyReservePctOverride] — Override the default safety reserve %.
  ///
  /// Returns null only if [vehicle] is null or [tripDistanceKm] ≤ 0.
  SmartTripCalculationResult? calculate({
    required EVVehicleModel? vehicle,
    required double currentBatteryPct,
    required double tripDistanceKm,
    double? safetyReservePctOverride,
  }) {
    if (vehicle == null || tripDistanceKm <= 0) return null;

    final safetyPct = safetyReservePctOverride ?? safetyReservePct;
    final batteryPct = currentBatteryPct.clamp(0.0, 100.0);

    // 1. Available energy from current battery level
    final availableEnergy = TripEnergyCalculator.calculateAvailableEnergy(
      batteryCapacityKwh: vehicle.usableBatteryCapacityKWh,
      batteryPct: batteryPct,
    );

    // 2. Estimated range from current battery
    final estimatedRange = TripEnergyCalculator.calculateEstimatedRange(
      availableEnergyKwh: availableEnergy,
      efficiencyWhPerKm: vehicle.averageEfficiencyWhPerKm,
    );

    // 3. Energy required for the full trip
    final tripEnergy = TripEnergyCalculator.calculateTripEnergy(
      tripDistanceKm: tripDistanceKm,
      efficiencyWhPerKm: vehicle.averageEfficiencyWhPerKm,
    );

    // 4. Required range including safety buffer
    final requiredRangeWithBuffer = TripEnergyCalculator.calculateRequiredRangeWithBuffer(
      tripDistanceKm: tripDistanceKm,
      safetyBufferPct: safetyPct,
    );

    // 5. Required battery % to complete without charging (with safety reserve)
    final tripEnergyPct = (tripEnergy / vehicle.usableBatteryCapacityKWh) * 100.0;
    final requiredBatteryWithReserve = tripEnergyPct + safetyPct;

    // 6. Estimated battery % at destination (no intermediate charging)
    final energyConsumedPct = (tripEnergy / vehicle.usableBatteryCapacityKWh) * 100.0;
    final estimatedBatteryAtDest = (batteryPct - energyConsumedPct).clamp(-100.0, 100.0);

    // 7. Charging required?
    final chargingRequired = estimatedRange < requiredRangeWithBuffer;

    // 8. Estimate minimum stops needed
    int stopsNeeded = 0;
    if (chargingRequired) {
      // How far can we go before hitting safety reserve floor?
      final safeRangeKm = estimatedRange - (safetyPct / 100.0 * vehicle.realWorldRangeKm);
      final remainingAfterFirstLeg = tripDistanceKm - safeRangeKm;
      if (remainingAfterFirstLeg > 0) {
        // Assume 75% charge target at each stop
        final chargeGainPct = SmartTripConfig.defaultChargingTargetPct -
            SmartTripConfig.minimumArrivalBatteryPct;
        final rangePerCharge = (chargeGainPct / 100.0) * vehicle.realWorldRangeKm;
        stopsNeeded = (remainingAfterFirstLeg / rangePerCharge).ceil().clamp(1, 10);
      } else {
        stopsNeeded = 1;
      }
    }

    return SmartTripCalculationResult(
      tripDistanceKm: tripDistanceKm,
      tripEnergyRequiredKWh: tripEnergy,
      requiredBatteryWithReservePct: requiredBatteryWithReserve.clamp(0.0, 200.0),
      estimatedBatteryAtDestinationPct: estimatedBatteryAtDest,
      chargingRequired: chargingRequired,
      estimatedChargingStopsNeeded: stopsNeeded,
      availableEnergyKWh: availableEnergy,
      estimatedRangeKm: estimatedRange,
      safetyReservePct: safetyPct,
    );
  }
}
