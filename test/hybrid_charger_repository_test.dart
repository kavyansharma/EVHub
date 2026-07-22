import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';

class MockFirestoreChargerRepository implements FirestoreChargerRepository {
  final List<MapMarkerModel> mockChargers;
  final bool shouldThrow;

  MockFirestoreChargerRepository({
    this.mockChargers = const [],
    this.shouldThrow = false,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getAllChargers) {
      if (shouldThrow) {
        throw Exception('Firestore connection failed');
      }
      return Future.value(mockChargers);
    }
    return super.noSuchMethod(invocation);
  }
}

class MockMapsService implements MapsService {
  final List<MapMarkerModel> mockPlacesChargers;
  final bool shouldThrow;

  MockMapsService({
    this.mockPlacesChargers = const [],
    this.shouldThrow = false,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getNearbyStations) {
      if (shouldThrow) {
        throw Exception('Google Places API network error');
      }
      return Future.value(mockPlacesChargers);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('MapMarkerModel Source Property Tests', () {
    test('default source is evhub_verified', () {
      const model = MapMarkerModel(
        id: 'test_1',
        title: 'Test Charger',
        description: 'Test Address',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
      );

      expect(model.source, equals('evhub_verified'));
    });

    test('custom source is preserved', () {
      const model = MapMarkerModel(
        id: 'places_1',
        title: 'Google Charger',
        description: 'Places Address',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'google_places',
        status: MarkerStatus.unknown,
      );

      expect(model.source, equals('google_places'));
      expect(model.status, equals(MarkerStatus.unknown));
    });
  });

  group('HybridChargerRepository Discovery & Deduplication Tests', () {
    const userLat = 28.6304;
    const userLng = 77.2177;

    test('combines Firestore and Google Places chargers with correct sources', () async {
      const firestoreCharger = MapMarkerModel(
        id: 'fs_1',
        title: 'Tata Power EV Charging Station',
        description: 'Connaught Place',
        latitude: 28.6305,
        longitude: 77.2178,
        type: MarkerType.station,
        source: 'evhub_verified',
      );

      const googleCharger = MapMarkerModel(
        id: 'gp_1',
        title: 'Statiq Charging Hub',
        description: 'Janpath',
        latitude: 28.6250,
        longitude: 77.2150,
        type: MarkerType.station,
        source: 'google_places',
      );

      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(mockChargers: [firestoreCharger]),
        mapsService: MockMapsService(mockPlacesChargers: [googleCharger]),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng);

      expect(results.length, equals(2));
      expect(results[0].source, equals('evhub_verified'));
      expect(results[1].source, equals('google_places'));
    });

    test('deduplicates chargers with same ID, keeping Firestore EVHub Verified charger', () async {
      const firestoreCharger = MapMarkerModel(
        id: 'shared_id_100',
        title: 'Tata Power Verified Charger',
        description: 'Connaught Place',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'evhub_verified',
      );

      const googleCharger = MapMarkerModel(
        id: 'shared_id_100',
        title: 'Tata Power Discovered Charger',
        description: 'Connaught Place Nearby',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'google_places',
      );

      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(mockChargers: [firestoreCharger]),
        mapsService: MockMapsService(mockPlacesChargers: [googleCharger]),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng);

      expect(results.length, equals(1));
      expect(results.first.id, equals('shared_id_100'));
      expect(results.first.source, equals('evhub_verified'));
      expect(results.first.title, equals('Tata Power Verified Charger'));
    });

    test('deduplicates chargers within 100m with similar names', () async {
      const firestoreCharger = MapMarkerModel(
        id: 'fs_charger',
        title: 'Zeon Fast Charging Station',
        description: 'Main Street',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'evhub_verified',
      );

      // Coordinates ~30m away, similar name
      const googleCharger = MapMarkerModel(
        id: 'gp_charger',
        title: 'Zeon Charging Station',
        description: 'Main Street Corner',
        latitude: 28.6306,
        longitude: 77.2178,
        type: MarkerType.station,
        source: 'google_places',
      );

      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(mockChargers: [firestoreCharger]),
        mapsService: MockMapsService(mockPlacesChargers: [googleCharger]),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng);

      expect(results.length, equals(1));
      expect(results.first.id, equals('fs_charger'));
      expect(results.first.source, equals('evhub_verified'));
    });

    test('filters out chargers beyond 20km search radius and sorts nearest first', () async {
      // Near charger: ~0.5 km away
      const nearCharger = MapMarkerModel(
        id: 'near',
        title: 'Near Station',
        description: '0.5km away',
        latitude: 28.6340,
        longitude: 77.2180,
        type: MarkerType.station,
        source: 'evhub_verified',
      );

      // Far charger: ~50 km away
      const farCharger = MapMarkerModel(
        id: 'far',
        title: 'Far Station',
        description: '50km away',
        latitude: 29.1000,
        longitude: 77.5000,
        type: MarkerType.station,
        source: 'evhub_verified',
      );

      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(mockChargers: [farCharger, nearCharger]),
        mapsService: MockMapsService(mockPlacesChargers: []),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng, radiusKm: 20.0);

      expect(results.length, equals(1));
      expect(results.first.id, equals('near'));
    });

    test('fault tolerance: continues showing Google Places chargers if Firebase fails', () async {
      const googleCharger = MapMarkerModel(
        id: 'gp_only',
        title: 'Google Places Charger',
        description: 'Location A',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'google_places',
      );

      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(shouldThrow: true),
        mapsService: MockMapsService(mockPlacesChargers: [googleCharger]),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng);

      expect(results.length, equals(1));
      expect(results.first.id, equals('gp_only'));
      expect(results.first.source, equals('google_places'));
    });

    test('fault tolerance: continues showing Firebase chargers if Google Places fails', () async {
      const firestoreCharger = MapMarkerModel(
        id: 'fs_only',
        title: 'Firebase Charger',
        description: 'Location B',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'evhub_verified',
      );

      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(mockChargers: [firestoreCharger]),
        mapsService: MockMapsService(shouldThrow: true),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng);

      expect(results.length, equals(1));
      expect(results.first.id, equals('fs_only'));
      expect(results.first.source, equals('evhub_verified'));
    });

    test('fault tolerance: returns empty list when both sources fail without crashing', () async {
      final repo = HybridChargerRepository(
        firestoreRepository: MockFirestoreChargerRepository(shouldThrow: true),
        mapsService: MockMapsService(shouldThrow: true),
      );

      final results = await repo.getHybridChargers(latitude: userLat, longitude: userLng);

      expect(results, isEmpty);
    });
  });
}
