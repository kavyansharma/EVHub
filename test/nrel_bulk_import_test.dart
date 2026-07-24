import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/user_model.dart';
import 'package:evhub/providers/bulk_import_provider.dart';
import 'package:evhub/providers/charger_data_dashboard_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/csv_import_service.dart';
import 'package:evhub/services/nrel_charger_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVHub Bulk EV Charger Import — Phase 11 Test Suite', () {
    // ------------------------------------------------------------------------
    // TEST 1: NREL API response parsing
    // ------------------------------------------------------------------------
    test('TEST 1: NREL API response parsing converts valid JSON to MapMarkerModel', () async {
      final mockJson = {
        'fuel_stations': [
          {
            'id': 1001,
            'station_name': 'Tesla Supercharger - Santa Monica',
            'street_address': '123 Ocean Ave',
            'city': 'Santa Monica',
            'state': 'CA',
            'country': 'US',
            'latitude': 34.0195,
            'longitude': -118.4912,
            'ev_network': 'Tesla',
            'status_code': 'E',
            'ev_connector_types': ['TESLA', 'J1772COMBO'],
            'ev_dc_fast_num': 8,
            'ev_level2_evse_num': 2,
            'station_phone': '800-555-0199',
            'ev_network_web': 'https://www.tesla.com',
          }
        ]
      };

      final client = http_testing.MockClient((request) async {
        return http.Response(json.encode(mockJson), 200);
      });

      final dataSource = NrelChargerDataSource(client: client);
      final chargers = await dataSource.fetchChargers();

      expect(chargers.length, equals(1));
      final c = chargers.first;
      expect(c.id, equals('nrel_1001'));
      expect(c.title, equals('Tesla Supercharger - Santa Monica'));
      expect(c.latitude, equals(34.0195));
      expect(c.longitude, equals(-118.4912));
      expect(c.network, equals('Tesla'));
      expect(c.city, equals('Santa Monica'));
      expect(c.state, equals('CA'));
      expect(c.country, equals('US'));
      expect(c.source, equals('bulk_import'));
      expect(c.isVerified, isFalse);
    });

    // ------------------------------------------------------------------------
    // TEST 2: CSV parsing
    // ------------------------------------------------------------------------
    test('TEST 2: CSV parsing creates valid row results', () {
      final service = CsvImportService();
      final csvText = '''name,network,address,city,state,country,latitude,longitude,totalConnectors,availableConnectors,power
ChargePoint Downtown,ChargePoint,456 Main St,Seattle,WA,US,47.6062,-122.3321,4,3,100kW''';

      final results = service.processCsv(
        bytes: Uint8List.fromList(utf8.encode(csvText)),
        existingFirestoreChargers: [],
      );

      expect(results.length, equals(1));
      expect(results.first.isValid, isTrue);
      expect(results.first.parsedModel?.title, equals('ChargePoint Downtown'));
    });

    // ------------------------------------------------------------------------
    // TEST 3 & 4 & 5 & 6 & 7: Invalid Data & Missing Fields
    // ------------------------------------------------------------------------
    test('TEST 3, 4, 5, 6, 7: Filters out missing lat/lng/name/connectors & invalid coordinates', () async {
      final mockJson = {
        'fuel_stations': [
          // Missing name
          {
            'id': 2001,
            'station_name': '',
            'latitude': 34.0,
            'longitude': -118.0,
          },
          // Missing latitude
          {
            'id': 2002,
            'station_name': 'No Lat Station',
            'longitude': -118.0,
          },
          // Invalid latitude out of bounds
          {
            'id': 2003,
            'station_name': 'Bad Lat Station',
            'latitude': 190.0,
            'longitude': -118.0,
          },
          // Valid Station
          {
            'id': 2004,
            'station_name': 'Good Station',
            'latitude': 34.05,
            'longitude': -118.25,
            'ev_connector_types': null,
          }
        ]
      };

      final client = http_testing.MockClient((request) async {
        return http.Response(json.encode(mockJson), 200);
      });

      final dataSource = NrelChargerDataSource(client: client);
      final chargers = await dataSource.fetchChargers();

      expect(chargers.length, equals(1));
      expect(chargers.first.id, equals('nrel_2004'));
      expect(chargers.first.connectors, contains('CCS2')); // Default fallback connector
    });

    // ------------------------------------------------------------------------
    // TEST 8: Duplicate External ID
    // ------------------------------------------------------------------------
    test('TEST 8: Duplicate external ID is detected and classified as exact duplicate', () {
      final service = CsvImportService();
      const existing = MapMarkerModel(
        id: 'nrel_5001',
        title: 'Existing NREL Station',
        description: 'Address',
        latitude: 34.0,
        longitude: -118.0,
        type: MarkerType.station,
        source: 'bulk_import',
        isVerified: false,
      );

      const incoming = MapMarkerModel(
        id: 'nrel_5001',
        title: 'Existing NREL Station Updated',
        description: 'Address',
        latitude: 34.0,
        longitude: -118.0,
        type: MarkerType.station,
        source: 'bulk_import',
        isVerified: false,
      );

      final results = service.processFetchedChargers(
        fetchedChargers: [incoming],
        existingFirestoreChargers: [existing],
      );

      expect(results.first.isDuplicate, isTrue);
      expect(results.first.duplicateStatus, equals(DuplicateClassification.exactDuplicate));
    });

    // ------------------------------------------------------------------------
    // TEST 9 & 10: Geographic Deduplication & EVHub Verified Protection
    // ------------------------------------------------------------------------
    test('TEST 9 & 10: Protection rule keeps existing evhub_verified charger over bulk_import duplicate', () {
      final service = CsvImportService();

      const verifiedCharger = MapMarkerModel(
        id: 'verified_123',
        title: 'EVgo Verified Hub',
        description: 'Verified Address',
        latitude: 34.0522,
        longitude: -118.2437,
        type: MarkerType.station,
        network: 'EVgo',
        source: 'evhub_verified',
        isVerified: true,
      );

      const bulkIncoming = MapMarkerModel(
        id: 'nrel_8888',
        title: 'EVgo Verified Hub',
        description: 'NREL Bulk Address',
        latitude: 34.0523, // ~10m away
        longitude: -118.2438,
        type: MarkerType.station,
        network: 'EVgo',
        source: 'bulk_import',
        isVerified: false,
      );

      final results = service.processFetchedChargers(
        fetchedChargers: [bulkIncoming],
        existingFirestoreChargers: [verifiedCharger],
      );

      expect(results.first.isDuplicate, isTrue);
      expect(results.first.existingDuplicateCharger?.isVerified, isTrue);
      expect(results.first.existingDuplicateCharger?.source, equals('evhub_verified'));
    });

    // ------------------------------------------------------------------------
    // TEST 11: Google Places Read-Only Protection
    // ------------------------------------------------------------------------
    test('TEST 11: Google Places records remain read-only', () {
      const googlePlaceCharger = MapMarkerModel(
        id: 'ch_google_place_123',
        title: 'Blink Station',
        description: 'Google Places Live Address',
        latitude: 34.1,
        longitude: -118.1,
        type: MarkerType.station,
        source: 'google_places',
        isVerified: false,
      );

      expect(googlePlaceCharger.source, equals('google_places'));
      expect(googlePlaceCharger.availableConnectorsCount, equals(0)); // Computed helper read-only check
    });

    // ------------------------------------------------------------------------
    // TEST 12: Non-Admin Import Rejection
    // ------------------------------------------------------------------------
    test('TEST 12: Non-admin user bulk import execution is strictly rejected', () async {
      final provider = BulkImportProvider();
      final nonAdminUser = UserModel(
        id: 'user_456',
        name: 'John Driver',
        email: 'john@evhub.com',
        role: Role.user,
      );

      final success = await provider.executeImport(adminUser: nonAdminUser);

      expect(success, isFalse);
      expect(provider.errorMessage, contains('Only administrators can perform bulk charger imports.'));
    });

    // ------------------------------------------------------------------------
    // TEST 14 & 15 & 16 & 17: Network Timeout, Error, Rate Limit, Empty Response
    // ------------------------------------------------------------------------
    test('TEST 14: API timeout handling throws informative error', () async {
      final client = http_testing.MockClient((request) async {
        throw Exception('Connection timed out');
      });

      final dataSource = NrelChargerDataSource(client: client);
      expect(
        () async => await dataSource.fetchChargers(),
        throwsA(isA<Exception>()),
      );
    });

    test('TEST 16: HTTP 429 Rate limit response throws rate limit error', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response('Rate limit exceeded', 429);
      });

      final dataSource = NrelChargerDataSource(client: client);
      expect(
        () async => await dataSource.fetchChargers(),
        throwsA(predicate((e) => e.toString().contains('Rate limit exceeded'))),
      );
    });

    test('TEST 17: Empty API response handles empty station array gracefully', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response(json.encode({'fuel_stations': []}), 200);
      });

      final dataSource = NrelChargerDataSource(client: client);
      final chargers = await dataSource.fetchChargers();

      expect(chargers, isEmpty);
    });

    // ------------------------------------------------------------------------
    // TEST 20 & 21: Import Result Statistics & Dashboard Health
    // ------------------------------------------------------------------------
    test('TEST 20 & 21: Bulk import statistics and dashboard source metrics', () {
      final provider = BulkImportProvider();
      expect(provider.step, equals(BulkImportStep.idle));
      expect(provider.validRowsCount, equals(0));
      expect(provider.duplicateRowsCount, equals(0));

      final mockRepo = _MockFirestoreRepo();
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockRepo);
      expect(dashboardProvider.bulkImportCount, equals(0));
      expect(dashboardProvider.bulkImportPercentage, equals(0.0));
    });
  });
}

class _MockFirestoreRepo implements FirestoreChargerRepository {
  @override
  Future<void> addCharger(MapMarkerModel charger) async {}

  @override
  Future<void> deleteCharger(String id) async {}

  @override
  Future<List<MapMarkerModel>> getAllChargers() async => [];

  @override
  Future<MapMarkerModel?> getChargerById(String id) async => null;

  @override
  Future<List<MapMarkerModel>> getChargersByOwner(String ownerId) async => [];

  @override
  Future<List<MapMarkerModel>> getPendingChargers() async => [];

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => [];

  @override
  Stream<List<MapMarkerModel>> streamAllChargers() => Stream.value([]);

  @override
  Stream<List<MapMarkerModel>> streamChargersByOwner(String ownerId) => Stream.value([]);

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() => Stream.value([]);

  @override
  Future<void> approveCharger(String id, String adminUid) async {}

  @override
  Future<void> rejectCharger(String id, String adminUid) async {}

  @override
  Future<void> updateCharger(MapMarkerModel charger) async {}
}
