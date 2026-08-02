import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/map_marker_model.dart';
import 'firestore_charger_repository.dart';
import '../services/maps_service.dart';

/// HybridChargerRepository
///
/// Combines EVHub Verified Chargers from Firebase Firestore with Live Discovered
/// Chargers from Google Places API. Handles deduplication, 20 km distance
/// filtering based on user GPS, distance sorting, and fault tolerant error handling.
class HybridChargerRepository {
  final FirestoreChargerRepository _firestoreRepository;
  final MapsService _mapsService;

  HybridChargerRepository({
    FirestoreChargerRepository? firestoreRepository,
    MapsService? mapsService,
  })  : _firestoreRepository = firestoreRepository ?? FirestoreChargerRepository(),
        _mapsService = mapsService ?? MapsService();

  /// Fetches EV chargers from both Firestore and Google Places API,
  /// deduplicates overlapping stations (preferring Firestore EVHub Verified chargers),
  /// filters by distance (default 20 km), and returns them sorted nearest-first.
  Future<List<MapMarkerModel>> getHybridChargers({
    required double latitude,
    required double longitude,
    double radiusKm = 20.0,
  }) async {
    List<MapMarkerModel> firebaseChargers = [];
    bool firebaseFailed = false;

    // 1. Fetch Firebase Verified Chargers (Only approved & verified chargers)
    try {
      firebaseChargers = await _firestoreRepository.getPublicVerifiedChargers();
      firebaseChargers = firebaseChargers
          .map((c) => _ensureSource(c, 'evhub_verified'))
          .toList();
    } catch (e) {
      firebaseFailed = true;
      debugPrint('[HybridChargerRepository] Firebase fetch failed: $e');
    }

    // 2. Fetch Google Places Live Discovered Chargers
    List<MapMarkerModel> googleChargers = [];
    bool googleFailed = false;
    try {
      googleChargers = await _mapsService.getNearbyStations(
        latitude,
        longitude,
        radiusKm,
      );
      googleChargers = googleChargers
          .map((c) => _ensureSource(c, 'google_places'))
          .toList();
    } catch (e) {
      googleFailed = true;
      debugPrint('[HybridChargerRepository] Google Places fetch failed: $e');
    }

    // Handle complete failure gracefully
    if (firebaseFailed && googleFailed) {
      debugPrint('[HybridChargerRepository] Error: Both Firebase and Google Places failed to load.');
      debugPrint('[HybridChargerRepository]');
      debugPrint('Firebase chargers: 0');
      debugPrint('Google Places chargers: 0');
      debugPrint('Duplicates removed: 0');
      debugPrint('Final chargers: 0');
      return [];
    }

    // 3. Deduplication
    // Keep EVHub Verified Firestore charger when a duplicate exists.
    final List<MapMarkerModel> merged = [];
    int duplicatesRemoved = 0;

    // Add all Firebase chargers first
    merged.addAll(firebaseChargers);

    // Filter Google Places chargers against existing merged chargers
    for (final gCharger in googleChargers) {
      final isDuplicate = merged.any((existing) => _isDuplicate(gCharger, existing));
      if (isDuplicate) {
        duplicatesRemoved++;
      } else {
        merged.add(gCharger);
      }
    }

    // 4. Distance Filtering & Sorting
    final List<_ChargerWithDistance> withDistance = [];
    for (final charger in merged) {
      final distanceMeters = Geolocator.distanceBetween(
        latitude,
        longitude,
        charger.latitude,
        charger.longitude,
      );
      final distanceKm = distanceMeters / 1000.0;

      if (distanceKm <= radiusKm) {
        withDistance.add(_ChargerWithDistance(charger, distanceKm));
      }
    }

    // Sort nearest distance first
    withDistance.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final List<MapMarkerModel> finalChargers =
        withDistance.map((e) => e.charger.copyWith(distanceKm: e.distanceKm)).toList();

    // 5. Debug Logging
    debugPrint('[HybridChargerRepository]');
    debugPrint('Firebase chargers: ${firebaseChargers.length}');
    debugPrint('Google Places chargers: ${googleChargers.length}');
    debugPrint('Duplicates removed: $duplicatesRemoved');
    debugPrint('Final chargers: ${finalChargers.length}');

    return finalChargers;
  }

  /// Searches nearby chargers centered around [latitude] and [longitude].
  /// Uses adaptive radius expansion starting at [initialRadiusKm] (default 25 km).
  /// Expands through 50 km, 100 km, 250 km, and 500 km until chargers are found,
  /// with an optional global India fallback if no chargers are nearby.
  Future<List<MapMarkerModel>> searchNearbyChargers({
    required double latitude,
    required double longitude,
    double initialRadiusKm = 25.0,
    double maxRadiusKm = 500.0,
    bool allowGlobalFallback = true,
  }) async {
    final List<double> radii = [initialRadiusKm, 50.0, 100.0, 250.0, maxRadiusKm];
    List<MapMarkerModel> results = [];
    double currentRadius = initialRadiusKm;

    for (final r in radii) {
      if (r < initialRadiusKm) continue;
      currentRadius = r;
      results = await getHybridChargers(
        latitude: latitude,
        longitude: longitude,
        radiusKm: currentRadius,
      );

      debugPrint('[MAP-DIAGNOSTIC] Radius search at $currentRadius km returned ${results.length} chargers');
      if (results.isNotEmpty) {
        break;
      }
    }

    // Global India Fallback: If still no chargers found within maxRadius, load all Firestore chargers sorted by distance
    if (results.isEmpty && allowGlobalFallback) {
      debugPrint('[MAP-DIAGNOSTIC] No chargers found within $maxRadiusKm km. Executing India-wide fallback...');
      try {
        final allFirebase = await _firestoreRepository.getPublicVerifiedChargers();
        if (allFirebase.isNotEmpty) {
          final List<_ChargerWithDistance> withDist = allFirebase.map((c) {
            final distM = Geolocator.distanceBetween(latitude, longitude, c.latitude, c.longitude);
            return _ChargerWithDistance(c.copyWith(distanceKm: distM / 1000.0), distM / 1000.0);
          }).toList();

          withDist.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          results = withDist.map((e) => e.charger).toList();
          debugPrint('[MAP-DIAGNOSTIC] Global India fallback loaded ${results.length} chargers across India');
        }
      } catch (e) {
        debugPrint('[MAP-DIAGNOSTIC] Global fallback error: $e');
      }
    }

    return results;
  }

  /// Mode 3: Route Chargers Engine
  /// Fetches all Firestore chargers and filters chargers located within [corridorRadiusKm] (default 10.0 km)
  /// of any point along the route [polylinePoints].
  /// Deduplicates chargers and sorts them in direction of travel (origin -> destination progress).
  Future<List<MapMarkerModel>> searchRouteCorridorChargers({
    required List<LatLng> polylinePoints,
    double corridorRadiusKm = 10.0,
  }) async {
    if (polylinePoints.isEmpty) return [];

    // Precalculate cumulative polyline distance array in km from origin
    final List<double> cumulativeDistKm = List<double>.filled(polylinePoints.length, 0.0);
    for (int i = 1; i < polylinePoints.length; i++) {
      final prev = polylinePoints[i - 1];
      final curr = polylinePoints[i];
      final segM = Geolocator.distanceBetween(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
      cumulativeDistKm[i] = cumulativeDistKm[i - 1] + (segM / 1000.0);
    }

    final List<MapMarkerModel> allChargers = await _firestoreRepository.getPublicVerifiedChargers();
    final List<MapMarkerModel> corridorChargers = [];
    final Map<String, double> routeProgressMap = {};

    for (final charger in allChargers) {
      if (!charger.hasValidCoordinates) continue;

      double minDistanceMeters = double.infinity;
      int bestPointIndex = 0;

      for (int i = 0; i < polylinePoints.length; i++) {
        final pt = polylinePoints[i];
        final distM = Geolocator.distanceBetween(
          pt.latitude,
          pt.longitude,
          charger.latitude,
          charger.longitude,
        );
        if (distM < minDistanceMeters) {
          minDistanceMeters = distM;
          bestPointIndex = i;
        }
      }

      final minDistanceKm = minDistanceMeters / 1000.0;
      if (minDistanceKm <= corridorRadiusKm) {
        final totalRouteKm = cumulativeDistKm.isNotEmpty ? cumulativeDistKm.last : 0.0;
        final progKm = cumulativeDistKm[bestPointIndex];
        final toDestKm = (totalRouteKm - progKm).clamp(0.0, double.infinity);
        corridorChargers.add(charger.copyWith(
          distanceKm: minDistanceKm,
          routeDistanceFromOriginKm: progKm,
          routeDistanceToDestKm: toDestKm,
        ));
        routeProgressMap[charger.id] = progKm;
      }
    }

    // Deduplicate chargers along corridor
    final List<MapMarkerModel> deduplicated = [];
    for (final c in corridorChargers) {
      if (!deduplicated.any((existing) => _isDuplicate(existing, c))) {
        deduplicated.add(c);
      }
    }

    // Sort in travel order (from origin to destination along route progress)
    deduplicated.sort((a, b) {
      final progA = routeProgressMap[a.id] ?? 0.0;
      final progB = routeProgressMap[b.id] ?? 0.0;
      return progA.compareTo(progB);
    });

    debugPrint('[ROUTE-CORRIDOR-ENGINE] Found ${deduplicated.length} deduplicated chargers (travel order sorted) within $corridorRadiusKm km corridor of ${polylinePoints.length} polyline points');
    return deduplicated;
  }

  /// Checks if two chargers are duplicates.
  /// Two chargers are considered duplicates when:
  /// 1. They have the same Google Place ID / ID, OR
  /// 2. Their coordinates are within ~100 meters AND normalized names are sufficiently similar.
  bool _isDuplicate(MapMarkerModel c1, MapMarkerModel c2) {
    // Check 1: Same ID / Place ID
    if (c1.id.isNotEmpty && c1.id == c2.id) {
      return true;
    }

    // Check 2: Coordinates within 100 meters AND normalized names are sufficiently similar
    final distanceMeters = Geolocator.distanceBetween(
      c1.latitude,
      c1.longitude,
      c2.latitude,
      c2.longitude,
    );

    if (distanceMeters <= 100.0 && _areNamesSimilar(c1.title, c2.title)) {
      return true;
    }

    return false;
  }

  /// Normalizes and compares charger title strings for similarity.
  bool _areNamesSimilar(String name1, String name2) {
    const stopWords = {'charger', 'charging', 'station', 'ev', 'fast', 'hub', 'point', 'ac', 'dc'};
    final norm1 = _normalizeName(name1);
    final norm2 = _normalizeName(name2);

    if (norm1.isEmpty || norm2.isEmpty) return false;
    if (norm1 == norm2) return true;

    final words1 = norm1.split(' ').where((w) => w.length > 2 && !stopWords.contains(w)).toSet();
    final words2 = norm2.split(' ').where((w) => w.length > 2 && !stopWords.contains(w)).toSet();

    if (words1.isEmpty || words2.isEmpty) return false;

    final intersection = words1.intersection(words2);
    if (intersection.isNotEmpty) {
      final minLength = words1.length < words2.length ? words1.length : words2.length;
      if (intersection.length / minLength >= 0.5) {
        return true;
      }
    }

    return false;
  }

  String _normalizeName(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  MapMarkerModel _ensureSource(MapMarkerModel model, String expectedSource) {
    if (model.source != expectedSource) {
      return MapMarkerModel(
        id: model.id,
        title: model.title,
        description: model.description,
        latitude: model.latitude,
        longitude: model.longitude,
        type: model.type,
        iconPath: model.iconPath,
        network: model.network,
        rating: model.rating,
        power: model.power,
        availableStalls: model.availableStalls,
        status: model.status,
        photoUrl: model.photoUrl,
        address: model.address,
        openStatus: model.openStatus,
        price: model.price,
        connectorCount: model.connectorCount,
        connectors: model.connectors,
        powerType: model.powerType,
        openingHours: model.openingHours,
        source: expectedSource,
      );
    }
    return model;
  }
}

class _ChargerWithDistance {
  final MapMarkerModel charger;
  final double distanceKm;

  const _ChargerWithDistance(this.charger, this.distanceKm);
}
