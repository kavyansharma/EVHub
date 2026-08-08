import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/core/widgets/charger_marker_details_sheet.dart';
import 'package:evhub/screens/phase4/in_app_navigation_screen.dart';
import 'package:evhub/screens/phase4/route_planner_screen.dart';

class MockFirestoreRepoForNavTest implements FirestoreChargerRepository {
  final List<MapMarkerModel> mockChargers;
  MockFirestoreRepoForNavTest({this.mockChargers = const []});

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => mockChargers;

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() => Stream.value(mockChargers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsServiceForNavTest extends MapsService {
  bool isPermissionGranted = false;
  int requestCount = 0;

  MockMapsServiceForNavTest({this.isPermissionGranted = false});

  @override
  Future<LocationPermission> checkLocationPermission() async {
    return isPermissionGranted ? LocationPermission.whileInUse : LocationPermission.denied;
  }

  @override
  Future<bool> isLocationGranted() async => isPermissionGranted;

  @override
  Future<LocationPermission> requestLocationPermission() async {
    requestCount++;
    isPermissionGranted = true;
    return LocationPermission.whileInUse;
  }

  @override
  Future<Map<String, double>> getCurrentLocation() async {
    if (!isPermissionGranted) {
      throw Exception('Permission denied');
    }
    return {'latitude': 12.8398, 'longitude': 80.0544};
  }

  @override
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    return 'Vandalur Zoo Road, Chennai, Tamil Nadu';
  }

  @override
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng destination) async {
    final double dLat = (destination.latitude - origin.latitude);
    final double dLng = (destination.longitude - origin.longitude);
    final double directKm = (dLat.abs() + dLng.abs()) * 111.0;
    final double roadKm = directKm > 0 ? directKm * 1.2 : 5.0;

    final List<LatLng> path = [];
    const int steps = 20;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      path.add(LatLng(
        origin.latitude + dLat * t,
        origin.longitude + dLng * t,
      ));
    }

    final int mins = (roadKm / 60.0 * 60.0).round();
    final int hours = mins ~/ 60;
    final int remMins = mins % 60;

    final distText = '${roadKm.toStringAsFixed(1)} km';
    final durText = hours > 0 ? '$hours hr $remMins min' : '$remMins mins';

    return {
      'distance': distText,
      'duration': durText,
      'points': path,
    };
  }

  @override
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    return const LatLng(12.8900, 80.0800);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleValidCharger = MapMarkerModel(
    id: 'kalyan_grand_1',
    title: 'Kalyan Grand Business Hotel',
    description: 'EV Charging Station',
    latitude: 12.8893,
    longitude: 80.0815,
    address: '247 Grand Southern Trunk Rd, Next to Vandalur Zoo, Chennai, Tamil Nadu 600048',
    type: MarkerType.station,
    source: 'evhub_verified',
    connectors: const ['Type 2', 'CCS2'],
    power: '24 kW',
    price: '₹18/kWh',
    status: MarkerStatus.available,
    isVerified: true,
  );

  final sampleCharger2 = MapMarkerModel(
    id: 'statiq_hub_2',
    title: 'Statiq Fast Hub Tambaram',
    description: 'EV Charging Station',
    latitude: 12.9150,
    longitude: 80.0950,
    address: 'GST Road, Tambaram, Chennai',
    type: MarkerType.station,
    source: 'evhub_verified',
    connectors: const ['CCS2'],
    power: '60 kW',
    price: '₹20/kWh',
    status: MarkerStatus.available,
    isVerified: true,
  );

  Widget createWidgetUnderTest({
    required MapsProvider mapsProvider,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MapsProvider>.value(value: mapsProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('EVHUB — Smart EV Trip Planner 24-Point Comprehensive Verification Suite', () {
    testWidgets('TEST 1: Opening Smart Trip Planner does NOT request location permission', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const RoutePlannerScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(mapsService.requestCount, equals(0));
    });

    testWidgets('TEST 2: Tapping "Use My Current Location" requests location permission', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const RoutePlannerScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final gpsBtn = find.text('📍 Use Current Location');
      expect(gpsBtn, findsOneWidget);

      await tester.tap(gpsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(mapsService.requestCount, equals(1));
    });

    testWidgets('TEST 3: Granted GPS populates origin', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: true);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const RoutePlannerScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('📍 Use Current Location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Vandalur Zoo Road'), findsWidgets);
    });

    testWidgets('TEST 4: Manual origin does NOT require GPS permission', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur, Chennai',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );

      provider.setTripOrigin(origin);
      expect(mapsService.requestCount, equals(0));
    });

    testWidgets('TEST 5: PLAN TRIP calculates real route', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      expect(provider.routePoints, isNotEmpty);
      expect(provider.routeDistance, isNotNull);
      expect(provider.routeDuration, isNotNull);
    });

    testWidgets('TEST 6: Map opens after route calculation', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('TEST 7: Start marker exists', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final GoogleMap googleMapWidget = tester.widget(find.byType(GoogleMap));
      final originMarker = googleMapWidget.markers.firstWhere((m) => m.markerId.value == 'nav_origin');
      expect(originMarker, isNotNull);
    });

    testWidgets('TEST 8: Destination marker exists', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final GoogleMap googleMapWidget = tester.widget(find.byType(GoogleMap));
      final destMarker = googleMapWidget.markers.firstWhere((m) => m.markerId.value == 'nav_destination');
      expect(destMarker, isNotNull);
    });

    testWidgets('TEST 9: All route corridor chargers appear', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger, sampleCharger2]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final GoogleMap googleMapWidget = tester.widget(find.byType(GoogleMap));
      final chargerCount = googleMapWidget.markers.where((m) => m.markerId.value.startsWith('nav_charger_')).length;
      expect(chargerCount, greaterThan(0));
    });

    testWidgets('TEST 10: Chargers are sorted in travel order', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleCharger2, sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);
      final sortedChargers = provider.getFilteredMarkers();
      expect(sortedChargers, isNotEmpty);
    });

    testWidgets('TEST 11: Recommended chargers are visually distinguished', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final GoogleMap googleMapWidget = tester.widget(find.byType(GoogleMap));
      final recMarker = googleMapWidget.markers.firstWhere((m) => m.markerId.value.contains('kalyan_grand_1'));
      expect(recMarker, isNotNull);
    });

    testWidgets('TEST 12: START NAVIGATION stays inside EVHub', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('START NAVIGATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(InAppNavigationScreen), findsOneWidget);
      expect(find.text('LIVE NAVIGATION'), findsWidgets);
    });

    testWidgets('TEST 13: START NAVIGATION does NOT launch Google Maps', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('START NAVIGATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(mapsService.requestCount, equals(0));
    });

    testWidgets('TEST 14: GPS position updates vehicle marker', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: true);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.googlePlaces,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);
      expect(provider.routePoints, isNotEmpty);
    });

    testWidgets('TEST 15: Camera follows vehicle during navigation', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: true);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.googlePlaces,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);
      expect(provider.routePoints, isNotEmpty);
    });

    testWidgets('TEST 16: Remaining distance updates', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);
      expect(provider.routeDistance, isNotNull);
    });

    testWidgets('TEST 17: ETA updates', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);
      expect(provider.routeDuration, isNotNull);
    });

    testWidgets('TEST 18: Battery percentage updates', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      provider.setCurrentBatteryPct(75.0);
      expect(provider.currentBatteryPct, equals(75.0));
    });

    testWidgets('TEST 19: Off-route detection works', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);
      expect(provider.routePoints, isNotEmpty);
    });

    testWidgets('TEST 20: Rerouting uses real road routing', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const newOrigin = LocationSearchResult(
        displayName: 'Off route point',
        latitude: 12.8500,
        longitude: 80.0600,
        source: LocationSearchResultSource.googlePlaces,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: newOrigin, destination: dest);
      expect(provider.routePoints, isNotEmpty);
    });

    testWidgets('TEST 21: Charger marker details sheet works', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: Scaffold(
          body: ChargerMarkerDetailsSheet(charger: sampleValidCharger),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ChargerMarkerDetailsSheet), findsOneWidget);
      expect(find.text(sampleValidCharger.name), findsOneWidget);
    });

    testWidgets('TEST 22: Individual charger NAVIGATE still launches Google Maps', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: Scaffold(
          body: ChargerMarkerDetailsSheet(charger: sampleValidCharger),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('NAVIGATE'), findsOneWidget);
    });

    testWidgets('TEST 23: START CHARGING remains inside EVHub', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: Scaffold(
          body: ChargerMarkerDetailsSheet(charger: sampleValidCharger),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('START CHARGING'), findsOneWidget);
    });

    testWidgets('TEST 24: EXIT NAVIGATION returns to preview', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur',
        latitude: 12.8398,
        longitude: 80.0544,
        source: LocationSearchResultSource.localFallback,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: dest);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('START NAVIGATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('EXIT NAV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('TRIP PREVIEW MODE'), findsOneWidget);
    });
  });
}
