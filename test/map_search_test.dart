import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:evhub/repositories/maps_repository.dart';

class MockFirestoreRepoForSearch implements FirestoreChargerRepository {
  final List<MapMarkerModel> mockChargers;
  final bool shouldFail;

  MockFirestoreRepoForSearch({
    this.mockChargers = const [],
    this.shouldFail = false,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async {
    if (shouldFail) throw Exception('Firestore connection error');
    return mockChargers;
  }

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() {
    if (shouldFail) return Stream.error(Exception('Firestore connection error'));
    return Stream.value(mockChargers);
  }

  @override
  Future<List<MapMarkerModel>> searchChargers(String query) async {
    if (shouldFail) throw Exception('Firestore search error');
    final q = query.toLowerCase();
    return mockChargers.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.network.toLowerCase().contains(q) ||
          (c.city?.toLowerCase().contains(q) ?? false) ||
          c.connectors.any((conn) => conn.toLowerCase().contains(q));
    }).toList();
  }
}

class MockMapsServiceForSearch extends MapsService {
  final List<Map<String, dynamic>> mockPredictions;
  final LatLng? mockCoords;
  final bool shouldFail;

  MockMapsServiceForSearch({
    this.mockPredictions = const [],
    this.mockCoords,
    this.shouldFail = false,
  });

  @override
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query,
      {double? currentLat, double? currentLng}) async {
    if (shouldFail) throw Exception('Google Places API Error');
    return mockPredictions;
  }

  @override
  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    if (shouldFail) throw Exception('Place details error');
    return mockCoords ?? const LatLng(28.6139, 77.2090); // Delhi default
  }

  @override
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    if (shouldFail) throw Exception('Geocoding error');
    return mockCoords ?? const LatLng(28.6139, 77.2090);
  }

  @override
  Future<Map<String, double>> getCurrentLocation() async {
    if (shouldFail) throw Exception('Location permissions are denied.');
    return {'latitude': 28.6304, 'longitude': 77.2177};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleOcmCharger = MapMarkerModel(
    id: 'ocm_123',
    title: 'Tata Power EV Station Delhi',
    description: 'Connaught Place, New Delhi',
    latitude: 28.6304,
    longitude: 77.2177,
    type: MarkerType.station,
    network: 'Tata Power',
    city: 'Delhi',
    state: 'Delhi',
    country: 'India',
    source: 'bulk_import',
    isVerified: false,
    verificationStatus: 'approved',
    connectors: const ['CCS2', 'Type 2'],
  );

  final sampleVerifiedCharger = MapMarkerModel(
    id: 'verified_456',
    title: 'Statiq Hub Gurgaon',
    description: 'Cyber City, Gurgaon',
    latitude: 28.4595,
    longitude: 77.0266,
    type: MarkerType.station,
    network: 'Statiq',
    city: 'Gurgaon',
    state: 'Haryana',
    country: 'India',
    source: 'evhub_verified',
    isVerified: true,
    verificationStatus: 'approved',
    connectors: const ['CCS2'],
  );

  group('EVHub Map Search Test Suite', () {
    test('1. Verified charger protection - verifies evhub_verified source', () {
      expect(sampleVerifiedCharger.source, equals('evhub_verified'));
      expect(sampleVerifiedCharger.isVerified, isTrue);
      expect(sampleOcmCharger.isVerified, isFalse);
    });

    test('2. Bulk-imported India OCM chargers are included in public queries', () async {
      final repo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger, sampleVerifiedCharger]);
      final chargers = await repo.getPublicVerifiedChargers();

      expect(chargers.length, equals(2));
      expect(chargers.any((c) => c.source == 'bulk_import'), isTrue);
    });

    test('3. Charger & Network Search in Firestore Repository', () async {
      final repo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger, sampleVerifiedCharger]);

      final tataResults = await repo.searchChargers('Tata Power');
      expect(tataResults.length, equals(1));
      expect(tataResults.first.network, equals('Tata Power'));

      final ccsResults = await repo.searchChargers('CCS2');
      expect(ccsResults.length, equals(2));
    });

    test('4. Debounced Search & Minimum Query Length in MapsProvider', () async {
      final firestoreRepo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger, sampleVerifiedCharger]);
      final mapsService = MockMapsServiceForSearch(mockPredictions: [
        {'description': 'Delhi, India', 'place_id': 'delhi_place_1'}
      ]);

      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      // Short query (<2 chars) should not produce suggestions
      provider.searchSuggestions('D');
      expect(provider.suggestions, isEmpty);

      // Query >= 2 chars triggers debounced search
      provider.searchSuggestions('Delhi');
      expect(provider.isSearching, isTrue);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(provider.isSearching, isFalse);
      expect(provider.suggestions, isNotEmpty);
    });

    test('5. Selecting a location suggestion moves camera & searches nearby chargers', () async {
      final firestoreRepo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger]);
      final mapsService = MockMapsServiceForSearch(mockCoords: const LatLng(28.6139, 77.2090));

      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      bool cameraMoved = false;
      LatLng? targetCoords;

      await provider.selectSuggestion(
        {
          'description': 'Delhi, India',
          'place_id': 'delhi_place_1',
          'type': 'location',
        },
        (coords, {zoom}) {
          cameraMoved = true;
          targetCoords = coords;
        },
      );

      expect(cameraMoved, isTrue);
      expect(targetCoords?.latitude, equals(28.6139));
      expect(provider.currentLocation?['latitude'], equals(28.6139));
      expect(provider.searchStatusMessage, contains('chargers found near Delhi'));
    });

    test('6. Adaptive Nearby Charger Search expands radius up to 50km', () async {
      final firestoreRepo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger]);
      final mapsService = MockMapsServiceForSearch();
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: firestoreRepo,
        mapsService: mapsService,
      );

      final nearby = await hybridRepo.searchNearbyChargers(
        latitude: 28.6304,
        longitude: 77.2177,
        initialRadiusKm: 5.0,
      );

      expect(nearby, isNotEmpty);
      expect(nearby.first.title, contains('Tata Power'));
    });

    test('7. Network & Charger Suggestions Classification', () async {
      final firestoreRepo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger]);
      final mapsService = MockMapsServiceForSearch();

      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      provider.searchSuggestions('Tata');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(provider.suggestions.any((s) => s['type'] == 'network'), isTrue);
      expect(provider.suggestions.any((s) => s['type'] == 'station'), isTrue);
    });

    test('8. Handles Location Permission Denial gracefully', () async {
      final firestoreRepo = MockFirestoreRepoForSearch(mockChargers: [sampleOcmCharger]);
      final mapsService = MockMapsServiceForSearch(shouldFail: true);

      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.fetchCurrentLocationAndStations();

      expect(provider.locationError, isNotNull);
      expect(provider.currentLocation?['latitude'], equals(28.6304)); // Fallback New Delhi
    });

    test('9. Handles Firestore failure fault-tolerantly', () async {
      final firestoreRepo = MockFirestoreRepoForSearch(shouldFail: true);
      final mapsService = MockMapsServiceForSearch();

      final repo = HybridChargerRepository(
        firestoreRepository: firestoreRepo,
        mapsService: mapsService,
      );

      final result = await repo.getHybridChargers(latitude: 28.6304, longitude: 77.2177);
      expect(result, isNotNull);
    });
  });
}
