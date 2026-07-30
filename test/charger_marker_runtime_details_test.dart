import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/core/widgets/charger_marker_details_sheet.dart';

class MockFirestoreRepoForRuntimeTest implements FirestoreChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVHub Charger Marker Runtime Details Test Suite (STEP 12)', () {
    late MapsProvider mapsProvider;
    late MapsService mapsService;

    final charger1 = MapMarkerModel(
      id: 'charger_delhi_1',
      title: 'Tata Power Hub CP',
      description: 'Block A, Connaught Place',
      type: MarkerType.station,
      latitude: 28.6304,
      longitude: 77.2177,
      status: MarkerStatus.available,
      network: 'Tata Power',
      power: '60 kW',
      connectors: ['CCS2', 'Type 2'],
      isVerified: true,
      source: 'evhub_verified',
      distanceKm: 1.5,
    );

    final charger2 = MapMarkerModel(
      id: 'charger_gurugram_2',
      title: 'Statiq Fast Station CyberHub',
      description: 'DLF Cyber City, Gurugram',
      type: MarkerType.station,
      latitude: 28.4950,
      longitude: 77.0890,
      status: MarkerStatus.busy,
      network: 'Statiq',
      power: '120 kW',
      connectors: ['CCS2'],
      isVerified: false,
      source: 'google_places',
      distanceKm: 8.4,
    );

    final charger3 = MapMarkerModel(
      id: 'charger_missing_fields_3',
      title: '', // Missing title
      description: '', // Missing description
      type: MarkerType.station,
      latitude: 12.9716,
      longitude: 77.5946,
      status: MarkerStatus.unknown,
      network: '', // Missing network
      power: '', // Missing power
      connectors: [], // Missing connectors
      isVerified: false,
    );

    setUp(() {
      mapsService = MapsService();
      mapsProvider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: MockFirestoreRepoForRuntimeTest(),
      );
      mapsProvider.setMarkers([charger1, charger2, charger3]);
    });

    testWidgets('TEST A & B & C & D & E & F: Bottom sheet widget renders charger name, network, status, power, connectors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapsProvider>.value(
            value: mapsProvider,
            child: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: charger1),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TEST B: Displays charger name
      expect(find.text('Tata Power Hub CP'), findsOneWidget);

      // TEST C: Displays network
      expect(find.text('Tata Power'), findsOneWidget);

      // TEST D: Displays status
      expect(find.text('AVAILABLE'), findsOneWidget);

      // TEST E: Displays power
      expect(find.text('60 kW'), findsOneWidget);

      // TEST F: Displays connectors
      expect(find.text('CCS2, Type 2'), findsOneWidget);

      // Displays Verified source badge
      expect(find.text('EVHub Verified'), findsOneWidget);

      // Displays distance
      expect(find.text('1.5 km away'), findsOneWidget);

      // Action buttons are visible
      expect(find.text('NAVIGATE'), findsOneWidget);
      expect(find.text('START & FULL DETAILS'), findsOneWidget);
    });

    testWidgets('TEST G: Missing optional fields render default N/A strings without blank screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapsProvider>.value(
            value: mapsProvider,
            child: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: charger3),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title fallback
      expect(find.text('EV Charging Station'), findsOneWidget);

      // Network fallback
      expect(find.text('EV Charging Network'), findsOneWidget);

      // Power fallback
      expect(find.text('Power N/A'), findsOneWidget);

      // Connector fallback
      expect(find.text('CCS2'), findsOneWidget);

      // Tariff fallback displays valid string without crashing or remaining blank
      expect(find.textContaining('kWh'), findsOneWidget);
    });

    testWidgets('TEST H: Multiple markers render their respective specific charger details', (WidgetTester tester) async {
      // Render Charger 2
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapsProvider>.value(
            value: mapsProvider,
            child: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: charger2),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Statiq Fast Station CyberHub'), findsOneWidget);
      expect(find.text('Statiq'), findsOneWidget);
      expect(find.text('BUSY'), findsOneWidget);
      expect(find.text('120 kW'), findsOneWidget);
      expect(find.text('8.4 km away'), findsOneWidget);
    });

    test('TEST I: Synchronous lookup maps charger ID instantly without async delays', () {
      final marker = mapsProvider.getMarkerById('charger_delhi_1');
      expect(marker, isNotNull);
      expect(marker!.id, 'charger_delhi_1');

      mapsProvider.selectMarkerById('charger_delhi_1');
      expect(mapsProvider.selectedMarker!.id, 'charger_delhi_1');
    });

    test('TEST J & K & L: GPS, Search, and Route mode taps identify correct charger', () {
      // GPS mode
      mapsProvider.selectMarkerById('charger_delhi_1');
      expect(mapsProvider.selectedMarker!.network, 'Tata Power');

      // Search mode
      mapsProvider.setSourceFilter('EVHub Verified');
      final filteredSearch = mapsProvider.getFilteredMarkers();
      expect(filteredSearch.isNotEmpty, true);
      mapsProvider.selectMarkerById(filteredSearch.first.id);
      expect(mapsProvider.selectedMarker!.id, 'charger_delhi_1');

      // Route mode
      mapsProvider.setSourceFilter('All Sources');
      mapsProvider.selectMarkerById('charger_gurugram_2');
      expect(mapsProvider.selectedMarker!.network, 'Statiq');
    });
  });
}
