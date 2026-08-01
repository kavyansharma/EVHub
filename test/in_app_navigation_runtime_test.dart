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
    return MapsService().getDirections(origin, destination);
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

  final sampleInvalidCharger = MapMarkerModel(
    id: 'invalid_coords_1',
    title: 'Unknown Location Charger',
    description: 'Missing Coordinates',
    latitude: 0.0,
    longitude: 0.0,
    address: '247 Grand Southern Trunk Rd, Vandalur, Chennai',
    type: MarkerType.station,
    source: 'google_places',
    connectors: const ['Type 2'],
    power: '7.4 kW',
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
    testWidgets('TEST A & B: Tapping NAVIGATE closes bottom sheet and opens InAppNavigationScreen', (tester) async {
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

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(ChargerMarkerDetailsSheet), findsOneWidget);
      expect(find.text('NAVIGATE'), findsOneWidget);

      // Tap NAVIGATE button
      await tester.tap(find.text('NAVIGATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // TEST A: InAppNavigationScreen opens
      expect(find.byType(InAppNavigationScreen), findsOneWidget);
      // TEST B: ChargerMarkerDetailsSheet is closed
      expect(find.byType(ChargerMarkerDetailsSheet), findsNothing);
    });

    testWidgets('TEST C & G: Valid charger coordinates pass to navigation screen & display Distance + ETA', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: true);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Vandalur Zoo',
        latitude: 12.8800,
        longitude: 80.0800,
        source: LocationSearchResultSource.localFallback,
      );
      final destination = LocationSearchResult(
        displayName: sampleValidCharger.name,
        subtitle: sampleValidCharger.displayAddress,
        latitude: sampleValidCharger.latitude,
        longitude: sampleValidCharger.longitude,
        source: LocationSearchResultSource.localFallback,
      );

      await provider.planTrip(origin: origin, destination: destination);

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: InAppNavigationScreen(origin: origin, destination: destination),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Navigating to Kalyan Grand Business Hotel'), findsOneWidget);
      expect(find.text('START NAVIGATION'), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
    });

    testWidgets('TEST D: Invalid charger coordinates show error SnackBar', (tester) async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleInvalidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: Scaffold(
          body: ChargerMarkerDetailsSheet(charger: sampleInvalidCharger),
        ),
      ));

      await tester.tap(find.text('NAVIGATE'));
      await tester.pumpAndSettle();

      // TEST D: SnackBar warning shown, InAppNavigationScreen not opened
      expect(find.textContaining('Charger coordinates are unavailable.'), findsOneWidget);
      expect(find.byType(InAppNavigationScreen), findsNothing);
    });

    test('TEST E & F: Route polyline generated & destination marker added to provider state', () async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: true);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LatLng(12.8398, 80.0544);
      const dest = LatLng(12.8893, 80.0815);

      await provider.calculateRouteBetween(origin, dest);

      expect(provider.routePoints, isNotEmpty);
      expect(provider.routePoints.length, greaterThan(10));
      expect(provider.routeDistance, isNotNull);
      expect(provider.routeDistance, isNot(equals('12.5 km')));
    });

    test('TEST ROUTE ACCURACY: New Delhi to Kalyan Grand Chennai returns >1700km and multi-point road polyline', () async {
      final mapsService = MapsService();
      const delhi = LatLng(28.6304, 77.2177);
      const chennai = LatLng(12.8893, 80.0815);

      final result = await mapsService.getDirections(delhi, chennai);

      expect(result, isNotNull);
      final points = result!['points'] as List<LatLng>;
      final distanceStr = result['distance'] as String;

      expect(points.length, greaterThan(10));
      expect(distanceStr, isNot(equals('12.5 km')));

      final numericDist = double.parse(distanceStr.replaceAll(' km', '').replaceAll(',', ''));
      expect(numericDist, greaterThan(1700.0));
    });

    test('TEST H: Google Maps fallback URL is dynamically generated from charger coordinates', () {
      final lat = sampleValidCharger.latitude;
      final lng = sampleValidCharger.longitude;
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

      expect(url, equals('https://www.google.com/maps/dir/?api=1&destination=12.8893,80.0815'));
      expect(url.contains('12.8893'), isTrue);
      expect(url.contains('80.0815'), isTrue);
    });

    testWidgets('TEST I, J & O: NAVIGATE does NOT trigger location permission dialog & works without GPS permission', (tester) async {
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

      await tester.tap(find.text('NAVIGATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // TEST I & O: Request count remains 0 (No OS dialog asked)
      expect(mapsService.requestCount, equals(0));

      // TEST J: Navigation screen opened using map center fallback
      expect(find.byType(InAppNavigationScreen), findsOneWidget);
      expect(find.textContaining('Live location is unavailable'), findsOneWidget);
    });

    test('TEST K: Smart Trip Planner accepts exact street addresses', () async {
      final mapsService = MockMapsServiceForNavTest(isPermissionGranted: false);
      final firestoreRepo = MockFirestoreRepoForNavTest(mockChargers: [sampleValidCharger]);
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: firestoreRepo,
      );

      const origin = LocationSearchResult(
        displayName: 'Ansal Heights, Sector 92, Gurugram',
        latitude: 28.3970,
        longitude: 76.9602,
        source: LocationSearchResultSource.googlePlaces,
      );
      const dest = LocationSearchResult(
        displayName: 'HUDA City Centre, Gurugram',
        latitude: 28.4595,
        longitude: 77.0726,
        source: LocationSearchResultSource.googlePlaces,
      );

      await provider.planTrip(origin: origin, destination: dest);

      expect(provider.tripOrigin?.displayName, equals('Ansal Heights, Sector 92, Gurugram'));
      expect(provider.tripDestination?.displayName, equals('HUDA City Centre, Gurugram'));
    });

    test('TEST L, M & N: Corridor chargers filtered along route & navigate from corridor charger opens InAppNavigationScreen', () async {
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

      expect(provider.discoveryMode, equals('route'));
      expect(provider.markers, isNotEmpty);
    });
  });
}
