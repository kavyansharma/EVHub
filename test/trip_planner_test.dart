import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/services/maps_service.dart';

class MockMapsRepo implements MapsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsServiceMock implements MapsService {
  @override
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng dest) async {
    final List<LatLng> points = [];
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = origin.latitude + t * (dest.latitude - origin.latitude);
      final lng = origin.longitude + t * (dest.longitude - origin.longitude);
      points.add(LatLng(lat, lng));
    }

    return {
      'distance': '280 km',
      'duration': '5 hr 30 min',
      'points': points,
    };
  }

  @override
  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirestoreRepoImpl implements FirestoreChargerRepository {
  final List<MapMarkerModel> mockChargers;
  MockFirestoreRepoImpl(this.mockChargers);

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async {
    return mockChargers;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 4 — Step 1: EV Trip Planner Unit & Integration Tests', () {
    late MapsProvider mapsProvider;
    late List<MapMarkerModel> firestoreChargers;

    const delhiLocation = LocationSearchResult(
      displayName: 'New Delhi, Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      source: LocationSearchResultSource.localFallback,
    );

    const jaipurLocation = LocationSearchResult(
      displayName: 'Jaipur, Rajasthan',
      latitude: 26.9124,
      longitude: 75.7873,
      source: LocationSearchResultSource.localFallback,
    );

    const mumbaiLocation = LocationSearchResult(
      displayName: 'Mumbai, Maharashtra',
      latitude: 19.0760,
      longitude: 72.8777,
      source: LocationSearchResultSource.localFallback,
    );

    const puneLocation = LocationSearchResult(
      displayName: 'Pune, Maharashtra',
      latitude: 18.5204,
      longitude: 73.8567,
      source: LocationSearchResultSource.localFallback,
    );

    const bengaluruLocation = LocationSearchResult(
      displayName: 'Bengaluru, Karnataka',
      latitude: 12.9716,
      longitude: 77.5946,
      source: LocationSearchResultSource.localFallback,
    );

    const chennaiLocation = LocationSearchResult(
      displayName: 'Chennai, Tamil Nadu',
      latitude: 13.0827,
      longitude: 80.2707,
      source: LocationSearchResultSource.localFallback,
    );

    setUp(() {
      firestoreChargers = [
        // Gurugram charger on Delhi -> Jaipur route
        const MapMarkerModel(
          id: 'delhi_jaipur_charger_1',
          title: 'Tata Power Gurugram Fast Charger',
          description: 'NH 48',
          latitude: 28.4595,
          longitude: 77.0266,
          type: MarkerType.station,
        ),
        // Lonavala charger on Mumbai -> Pune route
        const MapMarkerModel(
          id: 'mumbai_pune_charger_1',
          title: 'Statiq Lonavala Expressway Charger',
          description: 'Mumbai-Pune Expressway',
          latitude: 18.7557,
          longitude: 73.4091,
          type: MarkerType.station,
        ),
        // Hosur charger on Bengaluru -> Chennai route
        const MapMarkerModel(
          id: 'blr_chennai_charger_1',
          title: 'Zeon Hosur Highway Hub',
          description: 'NH 44 Hosur',
          latitude: 13.0100,
          longitude: 78.5000,
          type: MarkerType.station,
        ),
      ];

      final mockFsRepo = MockFirestoreRepoImpl(firestoreChargers);
      final mockMapsService = MockMapsServiceMock();
      final mockMapsRepo = MockMapsRepo();
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: mockFsRepo,
        mapsService: mockMapsService,
      );

      mapsProvider = MapsProvider(
        mapsRepository: mockMapsRepo,
        mapsService: mockMapsService,
        firestoreChargerRepository: mockFsRepo,
        hybridChargerRepository: hybridRepo,
      );
    });

    test('TEST A: Delhi -> Jaipur Trip Planning (Route, Polyline, 10 km Corridor Chargers)', () async {
      await mapsProvider.planTrip(origin: delhiLocation, destination: jaipurLocation);

      expect(mapsProvider.discoveryMode, equals('route'));
      expect(mapsProvider.tripOrigin, equals(delhiLocation));
      expect(mapsProvider.tripDestination, equals(jaipurLocation));
      expect(mapsProvider.routePoints, isNotEmpty);
      expect(mapsProvider.routeDistance, equals('280 km'));
      expect(mapsProvider.routeDuration, equals('5 hr 30 min'));

      final corridorChargers = mapsProvider.getFilteredMarkers();
      expect(corridorChargers.length, greaterThan(0));
      expect(corridorChargers.first.id, equals('delhi_jaipur_charger_1'));
    });

    test('TEST B: Mumbai -> Pune Trip Planning (10 km Corridor Chargers)', () async {
      await mapsProvider.planTrip(origin: mumbaiLocation, destination: puneLocation);

      expect(mapsProvider.discoveryMode, equals('route'));
      expect(mapsProvider.tripOrigin, equals(mumbaiLocation));
      expect(mapsProvider.tripDestination, equals(puneLocation));

      final corridorChargers = mapsProvider.getFilteredMarkers();
      expect(corridorChargers.length, greaterThan(0));
      expect(corridorChargers.first.id, equals('mumbai_pune_charger_1'));
    });

    test('TEST C: Bengaluru -> Chennai Trip Planning (10 km Corridor Chargers)', () async {
      await mapsProvider.planTrip(origin: bengaluruLocation, destination: chennaiLocation);

      expect(mapsProvider.discoveryMode, equals('route'));
      expect(mapsProvider.tripOrigin, equals(bengaluruLocation));
      expect(mapsProvider.tripDestination, equals(chennaiLocation));

      final corridorChargers = mapsProvider.getFilteredMarkers();
      expect(corridorChargers.length, greaterThan(0));
      expect(corridorChargers.first.id, equals('blr_chennai_charger_1'));
    });

    test('TEST D: Clear Trip resets route, polyline, markers, and restores GPS mode', () async {
      await mapsProvider.planTrip(origin: delhiLocation, destination: jaipurLocation);
      expect(mapsProvider.discoveryMode, equals('route'));
      expect(mapsProvider.routePoints, isNotEmpty);

      mapsProvider.clearTrip();

      expect(mapsProvider.discoveryMode, equals('gps'));
      expect(mapsProvider.tripOrigin, isNull);
      expect(mapsProvider.tripDestination, isNull);
      expect(mapsProvider.routePoints, isEmpty);
      expect(mapsProvider.routeDistance, isNull);
      expect(mapsProvider.routeDuration, isNull);
    });

    test('TEST E: Validation & Location State setters', () {
      mapsProvider.setTripOrigin(delhiLocation);
      expect(mapsProvider.tripOrigin, equals(delhiLocation));

      mapsProvider.setTripDestination(jaipurLocation);
      expect(mapsProvider.tripDestination, equals(jaipurLocation));

      // Same origin & destination validation equality check
      expect(delhiLocation.coordinates, equals(const LatLng(28.6139, 77.2090)));
      expect(jaipurLocation.coordinates, isNot(equals(delhiLocation.coordinates)));
    });
  });
}
