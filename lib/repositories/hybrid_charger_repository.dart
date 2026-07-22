import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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

    // 1. Fetch Firebase Verified Chargers
    try {
      firebaseChargers = await _firestoreRepository.getAllChargers();
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
    final norm1 = _normalizeName(name1);
    final norm2 = _normalizeName(name2);

    if (norm1.isEmpty || norm2.isEmpty) return false;
    if (norm1 == norm2) return true;
    if (norm1.contains(norm2) || norm2.contains(norm1)) return true;

    final words1 = norm1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = norm2.split(' ').where((w) => w.length > 2).toSet();

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
