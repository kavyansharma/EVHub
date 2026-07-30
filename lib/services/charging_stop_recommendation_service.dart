/// ChargingStopRecommendationService
///
/// Phase 4 Step 2 — Smart Charging Stop Algorithm.
///
/// Takes the existing route corridor chargers (from HybridChargerRepository)
/// and selects the optimal subset as recommended charging stops based on:
///   1. Direction of travel (forward along route only)
///   2. Vehicle range and safety reserve
///   3. Charger compatibility (connector type match)
///   4. Charger speed preference (fast > slow)
///   5. Safety reserve enforcement at every waypoint
library;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ev_vehicle_model.dart';
import '../models/map_marker_model.dart';
import '../models/recommended_charging_stop.dart';
import 'charging_time_estimator_service.dart';
import 'smart_trip_calculator_service.dart';
import 'smart_trip_energy_cost_service.dart';
import '../models/smart_trip_cost_settings.dart';

class ChargingStopRecommendationService {
  final ChargingTimeEstimatorService _timeEstimator;

  ChargingStopRecommendationService({
    ChargingTimeEstimatorService? timeEstimator,
  }) : _timeEstimator = timeEstimator ?? const ChargingTimeEstimatorService();

  /// Compute the recommended charging stops for a trip.
  ///
  /// [origin] — Route start point.
  /// [destination] — Route end point.
  /// [polylinePoints] — Decoded route polyline from Google Directions.
  /// [vehicle] — Selected EV vehicle profile.
  /// [currentBatteryPct] — Battery at trip start (0–100).
  /// [routeChargers] — All chargers within the 10 km route corridor.
  /// [safetyReservePct] — Minimum battery % to keep in reserve (default 15%).
  /// [preferCompatibleOnly] — When true, only considers connectors matching the vehicle.
  ///
  /// Returns [SmartTripResult] with recommended stops and trip summary.
  SmartTripResult recommend({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> polylinePoints,
    required EVVehicleModel vehicle,
    required double currentBatteryPct,
    required List<MapMarkerModel> routeChargers,
    required SmartTripCostSettings costSettings,
    double safetyReservePct = SmartTripConfig.defaultSafetyReservePct,
    bool preferCompatibleOnly = true,
  }) {
    // 1. Total trip distance
    final tripDistanceKm = _haversineKm(origin, destination);

    // 2. Energy calculation
    final efficiencyKWhPerKm =
        vehicle.usableBatteryCapacityKWh / vehicle.realWorldRangeKm;
    final tripEnergyKWh = tripDistanceKm * efficiencyKWhPerKm;
    final tripEnergyPct =
        (tripEnergyKWh / vehicle.usableBatteryCapacityKWh) * 100.0;
    final estimatedBattAtDestNoCharging =
        (currentBatteryPct - tripEnergyPct).clamp(-999.0, 100.0);
    final requiredBatteryPct = tripEnergyPct + safetyReservePct;
    final chargingRequired =
        currentBatteryPct < requiredBatteryPct;

    // 3. Position each charger along the route (0.0 = origin, 1.0 = destination)
    final positioned = _positionChargers(
      chargers: routeChargers,
      origin: origin,
      destination: destination,
      polylinePoints: polylinePoints,
      tripDistanceKm: tripDistanceKm,
    );

    // 4. Filter: keep only chargers in the forward direction
    final forward = positioned
        .where((c) => c.progressFraction >= 0.0 && c.progressFraction <= 1.0)
        .toList();
    forward.sort((a, b) => a.distanceFromOriginKm.compareTo(b.distanceFromOriginKm));

    debugPrint('[SmartTrip] Trip: ${tripDistanceKm.toStringAsFixed(1)}km, '
        'energy: ${tripEnergyKWh.toStringAsFixed(1)}kWh, '
        'battAtDest: ${estimatedBattAtDestNoCharging.toStringAsFixed(1)}%, '
        'chargingRequired: $chargingRequired, '
        'corridor chargers: ${routeChargers.length}, '
        'forward chargers: ${forward.length}');

    // 5. Split chargers into compatible vs all
    List<_PositionedCharger> candidates;
    bool compatibleFound = false;

    if (preferCompatibleOnly) {
      final compatible = forward
          .where((c) => _isCompatible(c.charger, vehicle.connectorTypes))
          .toList();
      if (compatible.isNotEmpty) {
        candidates = compatible;
        compatibleFound = true;
      } else {
        // Fall back to all chargers; UI will show "no compatible charger" warning
        candidates = forward;
        compatibleFound = false;
        debugPrint('[SmartTrip] No compatible charger found. Using all chargers as fallback.');
      }
    } else {
      candidates = forward;
      compatibleFound =
          forward.any((c) => _isCompatible(c.charger, vehicle.connectorTypes));
    }

    // 6. If charging not required, return empty stop list
    if (!chargingRequired) {
      debugPrint('[SmartTrip] No charging required for this trip.');
      return SmartTripResult(
        recommendedStops: const [],
        tripDistanceKm: tripDistanceKm,
        tripEnergyRequiredKWh: tripEnergyKWh,
        requiredBatteryPct: requiredBatteryPct,
        estimatedBatteryAtDestinationPct: estimatedBattAtDestNoCharging,
        chargingRequired: false,
        compatibleChargerFound: compatibleFound,
      );
    }

    // 7. Greedy algorithm: walk along the route and select stops
    final selectedStops = _selectStops(
      candidates: candidates,
      vehicle: vehicle,
      tripDistanceKm: tripDistanceKm,
      currentBatteryPct: currentBatteryPct,
      safetyReservePct: safetyReservePct,
      efficiencyKWhPerKm: efficiencyKWhPerKm,
      costSettings: costSettings,
    );

    // 8. Calculate estimated battery at destination after stops
    double finalBatteryPct = currentBatteryPct;
    for (final stop in selectedStops) {
      finalBatteryPct = stop.recommendedChargingTargetPct;
      // Simulate drive to next segment
      if (stop != selectedStops.last) {
        final nextStop = selectedStops[selectedStops.indexOf(stop) + 1];
        final segmentKm =
            nextStop.distanceFromStartKm - stop.distanceFromStartKm;
        final segmentEnergyPct =
            (segmentKm * efficiencyKWhPerKm / vehicle.usableBatteryCapacityKWh) * 100.0;
        finalBatteryPct -= segmentEnergyPct;
      }
    }

    // Remaining distance after last stop to destination
    if (selectedStops.isNotEmpty) {
      final lastStop = selectedStops.last;
      final remainingKm =
          tripDistanceKm - lastStop.distanceFromStartKm;
      final remainingEnergyPct =
          (remainingKm * efficiencyKWhPerKm / vehicle.usableBatteryCapacityKWh) *
              100.0;
      finalBatteryPct =
          (lastStop.recommendedChargingTargetPct - remainingEnergyPct)
              .clamp(-999.0, 100.0);
    }

    debugPrint('[SmartTrip] Selected ${selectedStops.length} charging stops.');
    for (final s in selectedStops) {
      debugPrint('[SmartTrip]   Stop ${s.stopIndex}: ${s.charger.title}, '
          '${s.distanceFromStartKm.toStringAsFixed(1)}km, '
          'arrival: ${s.estimatedArrivalBatteryPct.toStringAsFixed(1)}%, '
          'target: ${s.recommendedChargingTargetPct.toStringAsFixed(1)}%, '
          '~${s.estimatedChargingDurationMinutesInt} min');
    }

    // 9. Summarize Cost and Energy
    double totalEnergyAddedKwh = 0.0;
    double totalGridEnergyKwh = 0.0;
    double totalChargingLossKwh = 0.0;
    double totalChargingCost = 0.0;

    for (final stop in selectedStops) {
      totalEnergyAddedKwh += stop.energyAddedToBatteryKwh;
      totalGridEnergyKwh += stop.gridEnergyDrawnKwh;
      totalChargingLossKwh += stop.chargingLossKwh;
      totalChargingCost += stop.estimatedChargingCost;
    }

    final double avgCostPerKm = tripDistanceKm > 0 ? totalChargingCost / tripDistanceKm : 0.0;
    final double costPer100Km = avgCostPerKm * 100.0;

    return SmartTripResult(
      recommendedStops: selectedStops,
      tripDistanceKm: tripDistanceKm,
      tripEnergyRequiredKWh: tripEnergyKWh,
      requiredBatteryPct: requiredBatteryPct,
      estimatedBatteryAtDestinationPct: finalBatteryPct,
      chargingRequired: true,
      compatibleChargerFound: compatibleFound,
      totalEnergyAddedKwh: totalEnergyAddedKwh,
      totalGridEnergyKwh: totalGridEnergyKwh,
      totalChargingLossKwh: totalChargingLossKwh,
      totalChargingCost: totalChargingCost,
      averageCostPerKm: avgCostPerKm,
      costPer100Km: costPer100Km,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GREEDY STOP SELECTION ALGORITHM
  // ─────────────────────────────────────────────────────────────────────────

  List<RecommendedChargingStop> _selectStops({
    required List<_PositionedCharger> candidates,
    required EVVehicleModel vehicle,
    required double tripDistanceKm,
    required double currentBatteryPct,
    required double safetyReservePct,
    required double efficiencyKWhPerKm,
    required SmartTripCostSettings costSettings,
  }) {
    final costService = const SmartTripEnergyCostService();
    final stops = <RecommendedChargingStop>[];
    double batteryNow = currentBatteryPct;
    double positionKm = 0.0;
    int stopIndex = 1;

    // Sort: fast chargers first within same distance band, then by position
    final sorted = List<_PositionedCharger>.from(candidates);
    sorted.sort((a, b) {
      final posDiff = a.distanceFromOriginKm.compareTo(b.distanceFromOriginKm);
      if (posDiff != 0) return posDiff;
      // Within same position: prefer faster charger
      return b.chargerPowerKW.compareTo(a.chargerPowerKW);
    });

    // Maximum range considering safety reserve
    double safeRangeKm() {
      final safeEnergy = vehicle.usableBatteryCapacityKWh *
          ((batteryNow - safetyReservePct) / 100.0);
      if (safeEnergy <= 0) return 0.0;
      return safeEnergy / efficiencyKWhPerKm;
    }

    // How far can we go before hitting 10% floor (absolute minimum)?
    double absoluteRangeKm() {
      final minEnergy = vehicle.usableBatteryCapacityKWh *
          ((batteryNow - SmartTripConfig.minimumArrivalBatteryPct) / 100.0);
      if (minEnergy <= 0) return 0.0;
      return minEnergy / efficiencyKWhPerKm;
    }

    while (positionKm < tripDistanceKm) {
      final safeRange = safeRangeKm();
      final absoluteRange = absoluteRangeKm();

      // Can we reach destination without stopping?
      final remainingKm = tripDistanceKm - positionKm;
      final remainingEnergyPct =
          (remainingKm * efficiencyKWhPerKm / vehicle.usableBatteryCapacityKWh) * 100.0;

      if (batteryNow - remainingEnergyPct >= safetyReservePct) {
        // We can reach the destination with safety reserve — done!
        break;
      }

      // Find best charger in reachable range
      final reachableKm = positionKm + absoluteRange;

      // Preferred: within safe range first
      final inSafeRange = sorted.where(
        (c) =>
            c.distanceFromOriginKm > positionKm + 1.0 &&
            c.distanceFromOriginKm <= positionKm + safeRange,
      );

      // Fallback: stretch to absolute range if nothing in safe zone
      final inAbsoluteRange = sorted.where(
        (c) =>
            c.distanceFromOriginKm > positionKm + 1.0 &&
            c.distanceFromOriginKm <= reachableKm,
      );

      // Pick the LATEST charger within safe range (maximise driving, minimise stops)
      _PositionedCharger? chosen;
      if (inSafeRange.isNotEmpty) {
        // Among those in safe range, pick the furthest (to minimize stops)
        // but prefer fast chargers when distance is similar (within 20 km)
        final byDist = inSafeRange.toList()
          ..sort((a, b) => b.distanceFromOriginKm.compareTo(a.distanceFromOriginKm));
        final furthest = byDist.first;
        // Is there a faster charger within 20 km of the furthest?
        final fastOption = byDist.firstWhere(
          (c) =>
              furthest.distanceFromOriginKm - c.distanceFromOriginKm <= 20.0 &&
              c.chargerPowerKW > furthest.chargerPowerKW,
          orElse: () => furthest,
        );
        chosen = fastOption;
      } else if (inAbsoluteRange.isNotEmpty) {
        // Emergency: must stop but no safe-range charger found
        final byDist = inAbsoluteRange.toList()
          ..sort((a, b) => b.distanceFromOriginKm.compareTo(a.distanceFromOriginKm));
        chosen = byDist.first;
      } else {
        // No reachable charger — can't make the trip (handled in UI)
        break;
      }

      // Calculate battery on arrival at this charger
      final driveKm = chosen.distanceFromOriginKm - positionKm;
      final driveEnergyPct =
          (driveKm * efficiencyKWhPerKm / vehicle.usableBatteryCapacityKWh) * 100.0;
      final arrivalBatteryPct = (batteryNow - driveEnergyPct).clamp(0.0, 100.0);

      // Determine charging target
      double chargingTarget = SmartTripConfig.defaultChargingTargetPct;
      // If last leg after this stop to dest is long, charge more
      final distToDestFromStop =
          tripDistanceKm - chosen.distanceFromOriginKm;
      final energyNeededForLastLeg =
          (distToDestFromStop * efficiencyKWhPerKm / vehicle.usableBatteryCapacityKWh) *
              100.0;
      final neededTarget = energyNeededForLastLeg + safetyReservePct + 5.0; // 5% buffer
      if (neededTarget > chargingTarget) {
        chargingTarget = neededTarget.clamp(0.0, 90.0);
      }

      // Estimate charging time
      final timeEstimate = _timeEstimator.estimate(
        fromBatteryPct: arrivalBatteryPct,
        toBatteryPct: chargingTarget,
        batteryCapacityKWh: vehicle.usableBatteryCapacityKWh,
        chargerPowerKW: chosen.chargerPowerKW,
        vehicleMaxChargingKW: chosen.chargerPowerKW >= 22.0
            ? vehicle.maxDCChargingPowerKW
            : vehicle.maxACChargingPowerKW,
      );

      // Energy to add
      final energyToAddKWh =
          vehicle.usableBatteryCapacityKWh * (chargingTarget - arrivalBatteryPct) / 100.0;

      // Reason
      ChargingStopReason reason;
      if (arrivalBatteryPct <= safetyReservePct + 5.0) {
        reason = ChargingStopReason.batteryTooLow;
      } else if (inAbsoluteRange.isNotEmpty && inSafeRange.isEmpty) {
        reason = ChargingStopReason.noChargerAhead;
      } else {
        reason = ChargingStopReason.opportunisticTopUp;
      }

      // Phase 4 Step 3 Cost Calculations
      final energyNeededForStopKwh = driveKm * efficiencyKWhPerKm;
      final gridEnergyDrawnKwh = costService.calculateGridEnergyDrawn(energyToAddKWh, chosen.chargerPowerKW);
      final chargingLossKwh = (gridEnergyDrawnKwh - energyToAddKWh).clamp(0.0, double.infinity);
      final tariffInfo = costService.determineTariff(chosen.charger, costSettings);
      final estimatedChargingCost = costService.calculateChargingCost(gridEnergyDrawnKwh, tariffInfo.price);

      stops.add(RecommendedChargingStop(
        charger: chosen.charger,
        distanceFromStartKm: chosen.distanceFromOriginKm,
        distanceToDestinationKm:
            tripDistanceKm - chosen.distanceFromOriginKm,
        estimatedArrivalBatteryPct: arrivalBatteryPct,
        recommendedChargingTargetPct: chargingTarget,
        estimatedChargingEnergyKWh: energyToAddKWh,
        estimatedChargingDurationMinutes: timeEstimate.estimatedMinutes,
        reason: reason,
        stopIndex: stopIndex,
        isCompatible: _isCompatible(chosen.charger, vehicle.connectorTypes),
        energyNeededForStopKwh: energyNeededForStopKwh,
        gridEnergyDrawnKwh: gridEnergyDrawnKwh,
        chargingLossKwh: chargingLossKwh,
        pricePerKwh: tariffInfo.price,
        estimatedChargingCost: estimatedChargingCost,
        tariffSource: tariffInfo.source,
      ));

      // Update state for next iteration
      batteryNow = chargingTarget;
      positionKm = chosen.distanceFromOriginKm;
      stopIndex++;

      // Remove this charger from candidates to avoid picking it again
      sorted.remove(chosen);

      if (stopIndex > 10) break; // Safety cap
    }

    return stops;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /// Projects each charger onto the route and calculates its distance from origin.
  List<_PositionedCharger> _positionChargers({
    required List<MapMarkerModel> chargers,
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> polylinePoints,
    required double tripDistanceKm,
  }) {
    final result = <_PositionedCharger>[];
    final effective = polylinePoints.isNotEmpty ? polylinePoints : [origin, destination];

    for (final charger in chargers) {
      // Find the nearest polyline point to this charger
      double minDist = double.infinity;
      int nearestIdx = 0;
      for (int i = 0; i < effective.length; i++) {
        final d = Geolocator.distanceBetween(
          effective[i].latitude,
          effective[i].longitude,
          charger.latitude,
          charger.longitude,
        );
        if (d < minDist) {
          minDist = d;
          nearestIdx = i;
        }
      }

      // Cumulative distance along route to the nearest polyline point
      double cumulativeKm = 0.0;
      for (int i = 1; i <= nearestIdx; i++) {
        cumulativeKm += Geolocator.distanceBetween(
              effective[i - 1].latitude,
              effective[i - 1].longitude,
              effective[i].latitude,
              effective[i].longitude,
            ) /
            1000.0;
      }

      final progressFraction =
          tripDistanceKm > 0 ? cumulativeKm / tripDistanceKm : 0.0;

      final chargerPower =
          ChargingTimeEstimatorService.parsePowerKW(charger.power);

      result.add(_PositionedCharger(
        charger: charger,
        distanceFromOriginKm: cumulativeKm,
        progressFraction: progressFraction,
        chargerPowerKW: chargerPower > 0 ? chargerPower : 50.0,
      ));
    }

    return result;
  }

  /// Returns true if [charger] supports at least one connector in [vehicleConnectors].
  bool _isCompatible(MapMarkerModel charger, List<String> vehicleConnectors) {
    if (charger.connectors.isEmpty || vehicleConnectors.isEmpty) return true;
    return charger.connectors
        .any((c) => vehicleConnectors.any((v) => v.toLowerCase() == c.toLowerCase()));
  }

  /// Haversine distance in km between two LatLng points.
  double _haversineKm(LatLng a, LatLng b) {
    final distM = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    return distM / 1000.0;
  }
}

/// Internal class representing a charger projected onto the route.
class _PositionedCharger {
  final MapMarkerModel charger;
  final double distanceFromOriginKm;
  final double progressFraction; // 0.0 = origin, 1.0 = destination
  final double chargerPowerKW;

  const _PositionedCharger({
    required this.charger,
    required this.distanceFromOriginKm,
    required this.progressFraction,
    required this.chargerPowerKW,
  });
}
