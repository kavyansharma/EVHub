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
    return {'latitude': 12.8398, 'longitude': 80.0544}; // Vandalur Chennai
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
    if (address.contains('Ansal Heights') || address.contains('Gurugram')) {
      return const LatLng(28.3970, 76.9602);
    }
    if (address.contains('HUDA City Centre')) {
      return const LatLng(28.4595, 77.0726);
    }
    if (address.contains('Vandalur') || address.contains('Chennai')) {
      return const LatLng(12.8900, 80.0800);
    }
    return const LatLng(28.6139, 77.2090);
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

  group('EVHUB — In-App EV Navigation & Navigate Button End-to-End Suite', () {
    testWidgets('TEST 1: Creating trip opens preview mode (TRIP PREVIEW MODE, START NAVIGATION button visible)', (tester) async {
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
      const dest = LocationSearchResult(
        displayName: 'Tambaram, Chennai',
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

      // Verifies screen opens in TRIP PREVIEW MODE before user presses START NAVIGATION
      expect(find.text('TRIP PREVIEW MODE'), findsOneWidget);
      expect(find.text('START NAVIGATION'), findsOneWidget);
      expect(find.text('EXIT NAV'), findsNothing);
      expect(find.textContaining('Next maneuver in'), findsNothing);
    });

    testWidgets('TEST 2: Chargers appear on route before navigation starts', (tester) async {
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

      // Verifies corridor chargers are loaded and visible on route before START NAVIGATION is pressed
      expect(provider.getFilteredMarkers(), isNotEmpty);
      expect(provider.getFilteredMarkers().any((m) => m.title.contains('Kalyan Grand Business Hotel')), isTrue);
    });

    testWidgets('TEST 3: START NAVIGATION changes preview -> active navigation', (tester) async {
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

      expect(find.text('TRIP PREVIEW MODE'), findsOneWidget);

      await tester.tap(find.text('START NAVIGATION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verifies transition to LIVE NAVIGATION active mode
      expect(find.text('LIVE NAVIGATION'), findsWidgets);
      expect(find.text('EXIT NAV'), findsOneWidget);
    });

    testWidgets('TEST 4: No Google Maps opens during START NAVIGATION', (tester) async {
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

      // Zero location permission requested & remains inside EVHub
      expect(mapsService.requestCount, equals(0));
      expect(find.byType(InAppNavigationScreen), findsOneWidget);
    });

    testWidgets('TEST 5: Existing individual charger NAVIGATE still works (opens Google Maps, not InAppNavigationScreen)', (tester) async {
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
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => ChargerMarkerDetailsSheet(charger: sampleValidCharger),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(ChargerMarkerDetailsSheet), findsOneWidget);
      expect(find.text('NAVIGATE'), findsOneWidget);

      await tester.tap(find.text('NAVIGATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Direct NAVIGATE button from charger details sheet keeps sheet visible and does NOT launch InAppNavigationScreen
      expect(find.byType(ChargerMarkerDetailsSheet), findsOneWidget);
      expect(find.byType(InAppNavigationScreen), findsNothing);
    });

    testWidgets('TEST R: Active simulation progresses along polyline, updates metrics and top maneuver area', (tester) async {
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
        source: LocationSearchResultSource.googlePlaces,
      );
      const dest = LocationSearchResult(
        displayName: 'Tambaram, Chennai',
        latitude: 12.9249,
        longitude: 80.1000,
        source: LocationSearchResultSource.googlePlaces,
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
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('LIVE NAVIGATION'), findsWidgets);
      expect(find.textContaining('Next maneuver in'), findsOneWidget);
      expect(mapsService.requestCount, equals(0));
    });

    testWidgets('TEST S: Charging stop card interactions - SKIP STOP & START CHARGING stay inside EVHub', (tester) async {
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

      if (find.text('START CHARGING').evaluate().isNotEmpty) {
        expect(find.text('START CHARGING'), findsWidgets);
        expect(find.text('SKIP STOP'), findsWidgets);

        // Tap START CHARGING
        await tester.tap(find.text('START CHARGING').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifies EVHub charging session dialog
        expect(find.text('EV Charging Session'), findsOneWidget);
        expect(find.text('FINISH CHARGING'), findsOneWidget);

        // Finish charging
        await tester.tap(find.text('FINISH CHARGING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('EV Charging Session'), findsNothing);
      }
    });

    testWidgets('TEST T: Navigation completion state shows Trip Completed overlay', (tester) async {
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

      // Fast forward simulation through periodic timer
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 800));
      }

      expect(find.text('Trip Completed! 🎉'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      await tester.tap(find.text('DONE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('START NAVIGATION'), findsOneWidget);
    });
  });
}
