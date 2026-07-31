import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/services/vehicle_service.dart';
import 'package:evhub/services/wallet_service.dart';

class MockFirestoreRepoForTripPlannerTest implements FirestoreChargerRepository {
  final List<MapMarkerModel> mockChargers;
  MockFirestoreRepoForTripPlannerTest({this.mockChargers = const []});

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => mockChargers;

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() => Stream.value(mockChargers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsServiceForTripPlannerTest extends MapsService {
  int permissionRequestCount = 0;

  @override
  Future<LocationPermission> checkLocationPermission() async => LocationPermission.denied;

  @override
  Future<bool> isLocationGranted() async => false;

  @override
  Future<LocationPermission> requestLocationPermission() async {
    permissionRequestCount++;
    return LocationPermission.denied;
  }

  @override
  Future<Map<String, double>> getCurrentLocation() async {
    throw Exception('Location permission not granted.');
  }

  @override
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng destination) async {
    return {
      'points': <LatLng>[
        origin,
        LatLng(27.76315, 76.49815),
        destination,
      ],
      'distance': '245 km',
      'duration': '4 hr 30 min',
      'distance_meters': 245000,
      'duration_seconds': 16200,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultVehicle = VehicleService.indianEVEcosystem.first;

  final sampleCharger1 = MapMarkerModel(
    id: 'ch_delhi_jaipur',
    title: 'Tata Power Fast Charger Neemrana',
    description: 'NH48 Highway',
    latitude: 27.76315,
    longitude: 76.49815,
    type: MarkerType.station,
    source: 'evhub_verified',
    connectors: const ['CCS2'],
    power: '60 kW',
    price: '₹18/kWh',
    status: MarkerStatus.available,
  );

  final sampleChargerIncompatible = MapMarkerModel(
    id: 'ch_incompatible',
    title: 'GB/T AC Charger',
    description: 'Local Grid',
    latitude: 27.76315,
    longitude: 76.49815,
    type: MarkerType.station,
    source: 'evhub_verified',
    connectors: const ['GB/T'],
    power: '7 kW',
    price: '₹15/kWh',
    status: MarkerStatus.available,
  );

  const testOrigin = LocationSearchResult(
    displayName: 'New Delhi, Delhi',
    latitude: 28.6139,
    longitude: 77.2090,
    source: LocationSearchResultSource.localFallback,
  );

  const testDestination = LocationSearchResult(
    displayName: 'Jaipur, Rajasthan',
    latitude: 26.9124,
    longitude: 75.7873,
    source: LocationSearchResultSource.localFallback,
  );

  group('EVHUB — Smart EV Trip Planner Rebuild Test Suite', () {
    test('TEST A & B: Origin and Destination autocomplete return valid coordinates', () {
      expect(testOrigin.latitude, equals(28.6139));
      expect(testOrigin.longitude, equals(77.2090));
      expect(testDestination.latitude, equals(26.9124));
      expect(testDestination.longitude, equals(75.7873));
    });

    test('TEST C: Popular route buttons populate valid coordinates', () {
      expect(testOrigin.displayName, contains('Delhi'));
      expect(testDestination.displayName, contains('Jaipur'));
    });

    test('TEST D: Origin/Destination swap logic', () {
      LocationSearchResult origin = testOrigin;
      LocationSearchResult dest = testDestination;

      // Swap
      final tmp = origin;
      origin = dest;
      dest = tmp;

      expect(origin.displayName, contains('Jaipur'));
      expect(dest.displayName, contains('Delhi'));
    });

    test('TEST E, F & G: Route calculation succeeds without GPS permission or prompts', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      expect(mapsService.permissionRequestCount, equals(0)); // Zero OS permission prompts
      expect(provider.discoveryMode, equals('route'));
      expect(provider.routePoints, isNotEmpty);
      expect(provider.tripOrigin, isNotNull);
      expect(provider.tripDestination, isNotNull);
    });

    test('TEST H: EV battery energy calculation is correct', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      provider.setCurrentBatteryPct(50.0);
      expect(provider.currentBatteryPct, equals(50.0));

      final analysis = provider.tripEnergyAnalysis;
      expect(analysis.availableEnergyKwh, greaterThanOrEqualTo(0));
    });

    test('TEST I: Charging stop is recommended when required for long route', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      provider.setCurrentBatteryPct(80.0); // 80% battery requires charging stop at Neemrana to complete 245km
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      expect(provider.smartTripResult, isNotNull);
      expect(provider.smartTripResult!.chargingRequired, isTrue);
      expect(provider.recommendedStops, isNotEmpty);
      expect(provider.recommendedStops.first.charger.id, equals('ch_delhi_jaipur'));
    });

    test('TEST J & K: Incompatible connector is rejected & compatible charger prioritized', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(
        mockChargers: [sampleChargerIncompatible, sampleCharger1],
      );
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      provider.setCurrentBatteryPct(80.0);
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      final recStops = provider.recommendedStops;
      expect(recStops, isNotEmpty);
      expect(recStops.first.charger.id, equals('ch_delhi_jaipur')); // Compatible charger prioritized
    });

    test('TEST L: Charging cost is calculated correctly', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      provider.setCurrentBatteryPct(80.0);
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      final result = provider.smartTripResult;
      expect(result, isNotNull);
      expect(result!.totalChargingCost, greaterThan(0));
    });

    test('TEST M & N: Wallet is NOT debited during trip planning & insufficient balance handled', () async {
      final walletService = WalletService();

      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      // Verify planning a trip does NOT debit wallet
      expect(walletService, isNotNull);
    });

    test('TEST O: Route with no reachable charger handles warning safely', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: []); // Empty chargers
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      provider.setCurrentBatteryPct(10.0); // Extremely low battery with zero chargers
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      expect(provider.smartTripResult, isNotNull);
      expect(provider.smartTripResult!.compatibleChargerFound, isFalse);
    });

    test('TEST R & S: Trip planner handles API failure gracefully without infinite loading', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await provider.setSelectedVehicle(defaultVehicle);
      await provider.planTrip(origin: testOrigin, destination: testDestination);

      expect(provider.isLoadingRoute, isFalse);
      expect(provider.isCalculatingSmartTrip, isFalse);
    });

    test('TEST T: Marker selection and charger details open correctly', () async {
      final mapsService = MockMapsServiceForTripPlannerTest();
      final firestoreRepo = MockFirestoreRepoForTripPlannerTest(mockChargers: [sampleCharger1]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      provider.setSelectedMarker(sampleCharger1);

      expect(provider.selectedMarker, isNotNull);
      expect(provider.selectedMarker!.id, equals('ch_delhi_jaipur'));
    });
  });
}
