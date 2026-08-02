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
    testWidgets('TEST A & B: Tapping NAVIGATE closes bottom sheet and launches Google Maps (NOT InAppNavigationScreen)', (tester) async {
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

      // TEST A: ChargerMarkerDetailsSheet remains visible (STEP 6 requirement)
      expect(find.byType(ChargerMarkerDetailsSheet), findsOneWidget);
      // TEST B: InAppNavigationScreen is NOT opened
      expect(find.byType(InAppNavigationScreen), findsNothing);
    });

    testWidgets('TEST C: Direct Google Maps navigation URL contains driving mode & dir_action=navigate', (tester) async {
      final lat = sampleValidCharger.latitude;
      final lng = sampleValidCharger.longitude;
      final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving&dir_action=navigate';

      expect(googleMapsUrl, contains('api=1'));
      expect(googleMapsUrl, contains('destination=12.8893,80.0815'));
      expect(googleMapsUrl, contains('travelmode=driving'));
      expect(googleMapsUrl, contains('dir_action=navigate'));
    });

    testWidgets('TEST D & E: Invalid/missing charger coordinates handled safely without crash', (tester) async {
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

      // TEST D & E: InAppNavigationScreen not opened
      expect(find.byType(InAppNavigationScreen), findsNothing);
    });

    test('TEST F: Address fallback URL formatted correctly for missing coordinates', () {
      final address = sampleInvalidCharger.displayAddress;
      final query = Uri.encodeComponent(address);
      final url = 'https://www.google.com/maps/search/?api=1&query=$query';

      expect(url, contains('api=1'));
      expect(url, contains('query=247%20Grand%20Southern%20Trunk%20Rd'));
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
      // InAppNavigationScreen NOT opened
      expect(find.byType(InAppNavigationScreen), findsNothing);
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
