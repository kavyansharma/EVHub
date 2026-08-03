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
    return {'latitude': 12.8398, 'longitude': 80.0544};
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

  group('EVHUB — In-App EV Navigation 9-Point Verification Suite', () {
    testWidgets('1. Selecting route opens map screen', (tester) async {
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

      expect(find.byType(InAppNavigationScreen), findsOneWidget);
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(find.text('TRIP PREVIEW MODE'), findsOneWidget);
    });

    testWidgets('2. Route polyline is visible', (tester) async {
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

      await tester.pumpWidget(createWidgetUnderTest(
        mapsProvider: provider,
        child: const InAppNavigationScreen(origin: origin, destination: dest),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GoogleMap), findsOneWidget);
      final GoogleMap googleMapWidget = tester.widget(find.byType(GoogleMap));
      expect(googleMapWidget.polylines, isNotEmpty);
      expect(googleMapWidget.polylines.first.polylineId.value, equals('nav_route_polyline'));
    });

    testWidgets('3. Origin marker appears', (tester) async {
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
      expect(originMarker.position.latitude, equals(12.8398));
    });

    testWidgets('4. Destination marker appears', (tester) async {
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
      expect(destMarker.position.latitude, equals(12.9249));
    });

    testWidgets('5. Chargers along route appear', (tester) async {
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
      final chargerMarkerExists = googleMapWidget.markers.any((m) => m.markerId.value.startsWith('nav_charger_'));
      expect(chargerMarkerExists, isTrue);
    });

    testWidgets('6. Recommended chargers are highlighted', (tester) async {
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

    testWidgets('7. START NAVIGATION does not open Google Maps', (tester) async {
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
      expect(mapsService.requestCount, equals(0));
    });

    testWidgets('8. Navigation starts inside EVHub only', (tester) async {
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

      expect(find.text('LIVE NAVIGATION'), findsWidgets);
      expect(find.text('EXIT NAV'), findsOneWidget);

      final GoogleMap googleMapWidget = tester.widget(find.byType(GoogleMap));
      final vehicleMarker = googleMapWidget.markers.any((m) => m.markerId.value == 'active_vehicle_marker');
      expect(vehicleMarker, isTrue);
    });

    testWidgets('9. No location permission popup appears', (tester) async {
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

    testWidgets('Bonus test: Charger marker details sheet opens with VIEW DETAILS and NAVIGATE buttons', (tester) async {
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
      expect(find.text('VIEW DETAILS'), findsOneWidget);
      expect(find.text('NAVIGATE'), findsOneWidget);
    });
  });
}
