import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/core/widgets/charger_marker_details_sheet.dart';
import 'package:evhub/screens/phase4/charger_details_screen.dart';
import 'package:evhub/screens/phase4/in_app_navigation_screen.dart';

class MockFirestoreRepoForRuntimeDetailsTest implements FirestoreChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVHub Charger Details Bottom Sheet Runtime Test Suite', () {
    late MapsProvider mapsProvider;
    late MapsService mapsService;

    final testChargerComplete = MapMarkerModel(
      id: 'stat_delhi_999',
      title: 'Kashmere Gate Fast Charger',
      description: 'ISBT Kashmere Gate, New Delhi',
      type: MarkerType.station,
      latitude: 28.6665,
      longitude: 77.2333,
      status: MarkerStatus.available,
      network: 'Tata Power',
      power: '60 kW',
      connectors: ['CCS2', 'Type 2'],
      isVerified: true,
      source: 'evhub_verified',
      distanceKm: 3.2,
      price: '₹18/kWh',
    );

    final testChargerMissingFields = MapMarkerModel(
      id: 'stat_incomplete_888',
      title: '', // Missing name
      description: '', // Missing address/description
      type: MarkerType.station,
      latitude: 19.0760,
      longitude: 72.8777,
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
        firestoreChargerRepository: MockFirestoreRepoForRuntimeDetailsTest(),
      );
      mapsProvider.setMarkers([testChargerComplete, testChargerMissingFields]);
    });

    test('A. Marker tap passes charger object', () {
      mapsProvider.selectMarkerById('stat_delhi_999');
      expect(mapsProvider.selectedMarker, isNotNull);
      expect(mapsProvider.selectedMarker!.id, equals('stat_delhi_999'));
      expect(mapsProvider.selectedMarker!.name, equals('Kashmere Gate Fast Charger'));
    });

    testWidgets('B. Sheet receives correct charger & D. Sheet renders without exception', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: testChargerComplete),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify charger identity received & displayed correctly
      expect(find.text('Kashmere Gate Fast Charger'), findsOneWidget);
      expect(find.text('Tata Power'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('60 kW'), findsOneWidget);
      expect(find.text('CCS2, Type 2'), findsOneWidget);
      expect(find.text('ISBT Kashmere Gate, New Delhi'), findsOneWidget);
      expect(find.text('3.2 km away'), findsOneWidget);
      expect(find.text('NAVIGATE'), findsOneWidget);
      expect(find.text('START CHARGING'), findsOneWidget);
    });

    testWidgets('C. Missing fields show fallback text', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: testChargerMissingFields),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Name fallback
      expect(find.text('Unknown Charger'), findsOneWidget);

      // Network fallback
      expect(find.text('Unknown Network'), findsOneWidget);

      // Power fallback
      expect(find.text('Power unavailable'), findsOneWidget);

      // Connector fallback
      expect(find.text('Connector unavailable'), findsOneWidget);

      // Price fallback
      expect(find.text('Price unavailable'), findsOneWidget);
    });

    testWidgets('E. Navigate button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: testChargerComplete),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final navButton = find.text('NAVIGATE');
      expect(navButton, findsOneWidget);

      await tester.tap(navButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(InAppNavigationScreen), findsOneWidget);
    });

    testWidgets('F. Start charging button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapsProvider>.value(
          value: mapsProvider,
          child: MaterialApp(
            home: Scaffold(
              body: ChargerMarkerDetailsSheet(charger: testChargerComplete),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final startButton = find.text('START CHARGING');
      expect(startButton, findsOneWidget);

      await tester.tap(startButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pushes ChargerDetailsScreen
      expect(find.byType(ChargerDetailsScreen), findsOneWidget);
    });
  });
}
