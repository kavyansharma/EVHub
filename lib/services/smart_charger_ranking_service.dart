import 'dart:math' as math;
import '../models/map_marker_model.dart';
import 'charging_time_estimator_service.dart';

/// Supported sort modes for EV charger discovery.
enum SortOption {
  bestMatch,
  nearest,
  fastest,
  cheapest,
  bestForRoute,
}

/// EV compatibility status relative to a selected vehicle profile.
enum EVCompatibilityStatus {
  compatible,
  partiallyCompatible,
  incompatible,
  noVehicleSelected,
}

/// Rich recommendation wrapper containing charger model, calculated score,
/// ranking index, distances, compatibility status, and recommendation reason.
class SmartChargerRecommendation {
  final MapMarkerModel charger;
  final int rank;
  final double score;
  final double? distanceFromUserKm;
  final double? distanceFromRouteKm;
  final double? detourDistanceKm;
  final EVCompatibilityStatus compatibilityStatus;
  final String recommendationReason;

  const SmartChargerRecommendation({
    required this.charger,
    required this.rank,
    required this.score,
    this.distanceFromUserKm,
    this.distanceFromRouteKm,
    this.detourDistanceKm,
    required this.compatibilityStatus,
    required this.recommendationReason,
  });

  /// User-friendly compatibility label.
  String get compatibilityLabel {
    switch (compatibilityStatus) {
      case EVCompatibilityStatus.compatible:
        return 'COMPATIBLE';
      case EVCompatibilityStatus.partiallyCompatible:
        return 'PARTIALLY COMPATIBLE';
      case EVCompatibilityStatus.incompatible:
        return 'NOT COMPATIBLE';
      case EVCompatibilityStatus.noVehicleSelected:
        return 'Select your EV';
    }
  }

  /// Whether charger status is available.
  bool get isAvailable => charger.status == MarkerStatus.available;

  @override
  String toString() =>
      'SmartChargerRecommendation(#$rank, ${charger.title}, score: ${score.toStringAsFixed(1)}, '
      'reason: "$recommendationReason", status: ${charger.status.name})';
}

/// Core service responsible for ranking, scoring, sorting, and determining
/// EV compatibility for charging stations across GPS, Search, and Route modes.
class SmartChargerRankingService {
  const SmartChargerRankingService();

  /// Evaluates EV compatibility between [charger] connectors and [vehicleConnectors].
  static EVCompatibilityStatus checkCompatibility({
    required MapMarkerModel charger,
    required List<String>? vehicleConnectors,
  }) {
    if (vehicleConnectors == null || vehicleConnectors.isEmpty) {
      return EVCompatibilityStatus.noVehicleSelected;
    }

    if (charger.connectors.isEmpty) {
      return EVCompatibilityStatus.compatible; // Assume compatible if unspecified
    }

    final vCons = vehicleConnectors.map((c) => c.trim().toLowerCase()).toSet();
    final cCons = charger.connectors.map((c) => c.trim().toLowerCase()).toList();

    // Check exact connector match (e.g. CCS2 == CCS2)
    final hasExactMatch = cCons.any((c) => vCons.contains(c));
    if (hasExactMatch) {
      return EVCompatibilityStatus.compatible;
    }

    // Check partial / adapter compatibility (e.g. Type 2 AC charging)
    final hasPartialMatch = cCons.any((c) =>
        (c.contains('type 2') && vCons.any((v) => v.contains('type 2'))) ||
        (c.contains('ccs') && vCons.any((v) => v.contains('ccs'))));

    if (hasPartialMatch) {
      return EVCompatibilityStatus.partiallyCompatible;
    }

    return EVCompatibilityStatus.incompatible;
  }

  /// Ranks and sorts a list of [chargers] according to the selected [sortOption].
  List<SmartChargerRecommendation> rankAndSort({
    required List<MapMarkerModel> chargers,
    required SortOption sortOption,
    required Map<String, double>? userLocation,
    List<String>? vehicleConnectors,
    bool isRouteMode = false,
    double defaultPricePerKwh = 20.0,
  }) {
    if (chargers.isEmpty) return const [];

    final scoredList = <_ScoredCharger>[];

    for (final charger in chargers) {
      final compStatus = checkCompatibility(
        charger: charger,
        vehicleConnectors: vehicleConnectors,
      );

      final double distUser = charger.distanceKm ??
          (userLocation != null
              ? _haversineKm(
                  userLocation['latitude']!,
                  userLocation['longitude']!,
                  charger.latitude,
                  charger.longitude,
                )
              : 0.0);

      final double distRoute = charger.distanceKm ?? 0.0;
      final double detourKm = isRouteMode ? distRoute * 1.8 : 0.0; // Approx detour

      final double powerKw = ChargingTimeEstimatorService.parsePowerKW(charger.power);
      final double priceVal = _parsePrice(charger.price) ?? defaultPricePerKwh;

      // Multi-criteria weighted score
      double score = 100.0;

      // 1. Compatibility
      switch (compStatus) {
        case EVCompatibilityStatus.compatible:
          score += 40.0;
          break;
        case EVCompatibilityStatus.partiallyCompatible:
          score += 15.0;
          break;
        case EVCompatibilityStatus.incompatible:
          score -= 50.0;
          break;
        case EVCompatibilityStatus.noVehicleSelected:
          break;
      }

      // 2. Status Availability
      switch (charger.status) {
        case MarkerStatus.available:
          score += 35.0;
          break;
        case MarkerStatus.busy:
          score += 10.0;
          break;
        case MarkerStatus.unknown:
          score += 5.0;
          break;
        case MarkerStatus.offline:
          score -= 100.0;
          break;
      }

      // 3. Distance / Detour penalty
      final effectiveDist = isRouteMode ? detourKm : distUser;
      score -= math.min(effectiveDist * 1.5, 60.0);

      // 4. Power speed bonus (up to +40 points)
      score += math.min(powerKw * 0.35, 40.0);

      // 5. Price efficiency bonus (cheaper is higher score)
      if (priceVal > 0) {
        score -= math.min(priceVal * 0.8, 30.0);
      }

      // 6. EVHub verified bonus
      if (charger.isVerified || charger.source == 'evhub_verified') {
        score += 15.0;
      }

      // Determine recommendation reason based on strongest attributes
      String reason = 'EV Charging Station';
      if (isRouteMode && distRoute <= 2.0 && compStatus == EVCompatibilityStatus.compatible) {
        reason = 'Recommended for your route';
      } else if (compStatus == EVCompatibilityStatus.compatible && charger.status == MarkerStatus.available && powerKw >= 50.0) {
        reason = 'Best match for your EV';
      } else if (distUser <= 3.0 && charger.status == MarkerStatus.available) {
        reason = 'Nearest available charger';
      } else if (powerKw >= 100.0 && compStatus != EVCompatibilityStatus.incompatible) {
        reason = 'Fastest compatible charger';
      } else if (priceVal > 0 && priceVal < defaultPricePerKwh && compStatus != EVCompatibilityStatus.incompatible) {
        reason = 'Lowest known charging price';
      } else if (charger.isVerified) {
        reason = 'EVHub Verified';
      }

      scoredList.add(_ScoredCharger(
        charger: charger,
        score: score,
        distUser: distUser,
        distRoute: distRoute,
        detourKm: detourKm,
        powerKw: powerKw,
        priceVal: priceVal,
        compStatus: compStatus,
        reason: reason,
      ));
    }

    // Sort according to active sort option
    switch (sortOption) {
      case SortOption.bestMatch:
        scoredList.sort((a, b) => b.score.compareTo(a.score));
        break;
      case SortOption.nearest:
        scoredList.sort((a, b) => a.distUser.compareTo(b.distUser));
        break;
      case SortOption.fastest:
        scoredList.sort((a, b) => b.powerKw.compareTo(a.powerKw));
        break;
      case SortOption.cheapest:
        scoredList.sort((a, b) => a.priceVal.compareTo(b.priceVal));
        break;
      case SortOption.bestForRoute:
        scoredList.sort((a, b) {
          final detourDiff = a.detourKm.compareTo(b.detourKm);
          if (detourDiff != 0) return detourDiff;
          return b.score.compareTo(a.score);
        });
        break;
    }

    // Map to final 1-indexed recommendations
    return scoredList.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      return SmartChargerRecommendation(
        charger: item.charger,
        rank: idx,
        score: item.score,
        distanceFromUserKm: item.distUser,
        distanceFromRouteKm: item.distRoute,
        detourDistanceKm: item.detourKm,
        compatibilityStatus: item.compStatus,
        recommendationReason: item.reason,
      );
    }).toList();
  }

  /// Parses price string into double
  double? _parsePrice(String? priceStr) {
    if (priceStr == null || priceStr.isEmpty) return null;
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(priceStr);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Haversine distance in km
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0;
    final double dLat = _rad(lat2 - lat1);
    final double dLon = _rad(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _rad(double deg) => deg * (math.pi / 180.0);
}

class _ScoredCharger {
  final MapMarkerModel charger;
  final double score;
  final double distUser;
  final double distRoute;
  final double detourKm;
  final double powerKw;
  final double priceVal;
  final EVCompatibilityStatus compStatus;
  final String reason;

  const _ScoredCharger({
    required this.charger,
    required this.score,
    required this.distUser,
    required this.distRoute,
    required this.detourKm,
    required this.powerKw,
    required this.priceVal,
    required this.compStatus,
    required this.reason,
  });
}
