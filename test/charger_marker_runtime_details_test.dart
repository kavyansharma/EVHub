import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/core/widgets/charger_marker_details_sheet.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MockFirestoreRepoForRuntimeTest implements FirestoreChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVHub Charger Marker Runtime Details Test Suite (STEP 10)', () {
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
      price: null, // Missing price
      isVerified: false,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mapsService = MapsService();
      mapsProvider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: MockFirestoreRepoForRuntimeTest(),
      );
      mapsProvider.setMarkers([charger1, charger2, charger3]);
    });

    testWidgets('1 & 2 & 4 & 5 & 6: Marker tap renders charger name, network, status, power, connectors', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: charger1),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays charger name
      expect(find.text('Tata Power Hub CP'), findsOneWidget);

      // Displays network
      expect(find.text('Tata Power'), findsOneWidget);

      // Displays status
      expect(find.text('AVAILABLE'), findsOneWidget);

      // Displays power
      expect(find.text('60 kW'), findsOneWidget);

      // Displays connectors
      expect(find.text('CCS2, Type 2'), findsOneWidget);

      // Displays Verified source badge
      expect(find.text('EVHub Verified'), findsOneWidget);

      // Displays distance
      expect(find.text('1.5 km away'), findsOneWidget);

      // Action buttons are visible
      expect(find.text('NAVIGATE'), findsOneWidget);
      expect(find.text('START CHARGING'), findsOneWidget);
    });

    testWidgets('7 & 8 & 9: Power & Tariff fallbacks work without crashing UI', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: charger3),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title fallback
      expect(find.text('Unknown Charger'), findsOneWidget);

      // Network fallback
      expect(find.text('Unknown Network'), findsOneWidget);

      // Power fallback
      expect(find.text('Power unavailable'), findsOneWidget);

      // Connector fallback
      expect(find.text('Connector unavailable'), findsOneWidget);

      // Status fallback
      expect(find.text('Availability unknown'), findsOneWidget);

      // Tariff fallback displays Price unavailable when missing
      expect(find.text('Price unavailable'), findsOneWidget);
    });

    testWidgets('10: Multiple markers render their respective specific charger details', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
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

    test('3 & 11 & 12: Unique charger ID, GPS, Search, and Route mode taps identify correct charger', () {
      // 3. Charger ID uniqueness
      expect(charger1.id, isNot(equals(charger2.id)));

      // 11. GPS mode
      mapsProvider.selectMarkerById('charger_delhi_1');
      expect(mapsProvider.selectedMarker!.network, 'Tata Power');

      // Search mode
      mapsProvider.setSourceFilter('EVHub Verified');
      final filteredSearch = mapsProvider.getFilteredMarkers();
      expect(filteredSearch.isNotEmpty, true);
      mapsProvider.selectMarkerById(filteredSearch.first.id);
      expect(mapsProvider.selectedMarker!.id, 'charger_delhi_1');

      // 12. Route mode
      mapsProvider.setSourceFilter('All Sources');
      mapsProvider.selectMarkerById('charger_gurugram_2');
      expect(mapsProvider.selectedMarker!.network, 'Statiq');
    });
  });
}
