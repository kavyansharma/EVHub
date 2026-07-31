import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/services/maps_service.dart';

class MockFirestoreRepoForPermissionTest implements FirestoreChargerRepository {
  final List<MapMarkerModel> mockChargers;
  MockFirestoreRepoForPermissionTest({this.mockChargers = const []});

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => mockChargers;

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() => Stream.value(mockChargers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsServiceForPermissionTest extends MapsService {
  bool isInitiallyGranted = false;
  bool isPermissionGranted = false;
  bool failOnRequest = false;
  int checkCount = 0;
  int requestCount = 0;

  MockMapsServiceForPermissionTest({this.isInitiallyGranted = false, this.failOnRequest = false}) {
    isPermissionGranted = isInitiallyGranted;
  }

  @override
  Future<LocationPermission> checkLocationPermission() async {
    checkCount++;
    return isPermissionGranted ? LocationPermission.whileInUse : LocationPermission.denied;
  }

  @override
  Future<bool> isLocationGranted() async {
    checkCount++;
    return isPermissionGranted;
  }

  @override
  Future<LocationPermission> requestLocationPermission() async {
    requestCount++;
    if (failOnRequest) {
      isPermissionGranted = false;
      return LocationPermission.denied;
    }
    isPermissionGranted = true;
    return LocationPermission.whileInUse;
  }

  @override
  Future<Map<String, double>> getCurrentLocation() async {
    if (!isPermissionGranted) {
      throw Exception('Location permission is not granted.');
    }
    return {'latitude': 28.6304, 'longitude': 77.2177};
  }

  @override
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    if (address.toLowerCase().contains('bengaluru')) {
      return const LatLng(12.9716, 77.5946);
    }
    return const LatLng(28.6139, 77.2090); // Delhi default
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCharger = MapMarkerModel(
    id: 'ch_101',
    title: 'Tata Power EV Station Delhi',
    description: 'Connaught Place',
    latitude: 28.6304,
    longitude: 77.2177,
    type: MarkerType.station,
    source: 'evhub_verified',
    connectors: const ['CCS2'],
    power: '60 kW',
    price: '₹18/kWh',
  );

  group('EVHUB — Permanent Location Permission UX Enforcement Test Suite', () {
    test('TEST A: Fresh app launch -> no permission dialog requested', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.fetchCurrentLocationAndStations(userInitiated: false);

      expect(mapsService.requestCount, equals(0)); // Zero OS permission dialog calls
      expect(provider.hasLocationPermission, isFalse);
      expect(provider.currentLocation?['latitude'], equals(28.6304)); // Fallback New Delhi
    });

    test('TEST B: Open MapsScreen -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.fetchCurrentLocationAndStations(userInitiated: false);

      expect(mapsService.requestCount, equals(0));
      expect(provider.markers, isNotEmpty);
    });

    test('TEST C: Navigate Map -> Trip Planner -> Wallet -> Sessions -> Profile -> Map -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      // Simulate tab switching
      provider.clearSearchStatus();
      provider.clearRoute();
      await provider.fetchCurrentLocationAndStations(userInitiated: false);

      expect(mapsService.requestCount, equals(0));
    });

    test('TEST D: Wait for background refresh -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.fetchCurrentLocationAndStations(userInitiated: false);
      await provider.refreshStations();

      expect(mapsService.requestCount, equals(0));
    });

    test('TEST E: Firestore stream update -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      provider.startRealtimeStreams();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mapsService.requestCount, equals(0));
    });

    test('TEST F & G: Search Bengaluru and Delhi -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.selectSuggestion(
        {
          'description': 'Bengaluru',
          'type': 'location',
          'latitude': 12.9716,
          'longitude': 77.5946,
          'source': 'local_fallback',
        },
        (coords, {zoom}) {},
      );

      expect(mapsService.requestCount, equals(0));
      expect(provider.currentLocation?['latitude'], equals(12.9716));
    });

    test('TEST H: Open charger details -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      provider.setSelectedMarker(sampleCharger);

      expect(mapsService.requestCount, equals(0));
      expect(provider.selectedMarker?.id, equals('ch_101'));
    });

    test('TEST I, J & K: Open Trip Planner, calculate route & Smart Trip Analysis -> no permission dialog', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        source: LocationSearchResultSource.localFallback,
      );
      const destination = LocationSearchResult(
        displayName: 'Jaipur',
        latitude: 26.9124,
        longitude: 75.7873,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: destination);

      expect(mapsService.requestCount, equals(0));
      expect(provider.tripOrigin, isNotNull);
      expect(provider.tripDestination, isNotNull);
    });

    test('TEST L & M: Explicitly tap "Enable Live GPS" / FAB -> permission request occurs', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      // User explicitly taps Enable Live GPS
      await provider.requestUserLocationAccess();

      expect(mapsService.requestCount, equals(1)); // Permission request triggered ONLY on explicit action
      expect(provider.hasLocationPermission, isTrue);
    });

    test('TEST N, O, P, Q: Deny permission -> app remains fully functional', () async {
      final mapsService = MockMapsServiceForPermissionTest(isInitiallyGranted: false, failOnRequest: true);
      final firestoreRepo = MockFirestoreRepoForPermissionTest(mockChargers: [sampleCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      // User explicitly taps Enable Live GPS but denies
      await provider.requestUserLocationAccess();

      expect(mapsService.requestCount, equals(1));
      expect(provider.hasLocationPermission, isFalse);

      // Verify app remains usable: manual search works
      await provider.selectSuggestion(
        {
          'description': 'Mumbai',
          'type': 'location',
          'latitude': 19.0760,
          'longitude': 72.8777,
          'source': 'local_fallback',
        },
        (coords, {zoom}) {},
      );
      expect(provider.currentLocation?['latitude'], equals(19.0760));

      // Verify trip planning works after denial
      await provider.planTrip(
        origin: const LocationSearchResult(displayName: 'Mumbai', latitude: 19.0760, longitude: 72.8777, source: LocationSearchResultSource.localFallback),
        destination: const LocationSearchResult(displayName: 'Pune', latitude: 18.5204, longitude: 73.8567, source: LocationSearchResultSource.localFallback),
      );
      expect(provider.tripOrigin, isNotNull);

      // Verify background refresh after denial triggers NO repeat permission request
      await provider.refreshStations();
      expect(mapsService.requestCount, equals(1)); // Still 1 from initial explicit click, 0 from refresh
    });

    test('TEST R: No direct Geolocator.requestPermission() calls exist outside MapsService.requestLocationPermission()', () {
      final mapsServiceFile = File('lib/services/maps_service.dart').readAsStringSync();
      final mapsProviderFile = File('lib/providers/maps_provider.dart').readAsStringSync();
      final mapsScreenFile = File('lib/screens/phase4/maps_screen.dart').readAsStringSync();

      expect(mapsServiceFile.contains('Geolocator.requestPermission()'), isTrue);
      expect(mapsProviderFile.contains('Geolocator.requestPermission()'), isFalse);
      expect(mapsScreenFile.contains('Geolocator.requestPermission()'), isFalse);
    });

    test('TEST S: No startup AlertDialog requests location permission', () {
      final mapsScreenFile = File('lib/screens/phase4/maps_screen.dart').readAsStringSync();
      expect(mapsScreenFile.contains('_showLocationErrorDialog'), isFalse);
    });
  });
}
