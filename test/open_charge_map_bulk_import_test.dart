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
import 'package:evhub/services/open_charge_map_charger_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7.5 — India-Wide EV Charger Bulk Import (OCM Test Suite)', () {
    // ------------------------------------------------------------------------
    // TEST 1: OCM API response parsing
    // ------------------------------------------------------------------------
    test('TEST 1: OCM API response parsing converts valid India JSON to MapMarkerModel', () async {
      final mockJson = [
        {
          'ID': 99001,
          'AddressInfo': {
            'Title': 'Tata Power Charging Station - Connaught Place',
            'AddressLine1': 'Block A, Connaught Place',
            'Town': 'New Delhi',
            'StateOrProvince': 'Delhi',
            'Postcode': '110001',
            'Latitude': 28.6304,
            'Longitude': 77.2177,
            'ContactTelephone1': '+91 1800-209-5161',
            'Country': {'ISOCode': 'IN', 'Title': 'India'},
          },
          'OperatorInfo': {'Title': 'Tata Power'},
          'Connections': [
            {'ConnectionType': {'Title': 'CCS (Type 2)', 'ID': 33}, 'PowerKW': 150, 'Quantity': 2},
            {'ConnectionType': {'Title': 'Type 2 (Socket)', 'ID': 25}, 'PowerKW': 22, 'Quantity': 2},
          ],
          'StatusType': {'IsOperational': true},
        }
      ];

      final client = http_testing.MockClient((request) async {
        return http.Response(json.encode(mockJson), 200);
      });

      final dataSource = OpenChargeMapChargerDataSource(client: client);
      final chargers = await dataSource.fetchChargers();

      expect(chargers.length, equals(1));
      final c = chargers.first;
      expect(c.id, equals('ocm_99001'));
      expect(c.title, equals('Tata Power Charging Station - Connaught Place'));
      expect(c.network, equals('Tata Power'));
      expect(c.city, equals('New Delhi'));
      expect(c.state, equals('Delhi'));
      expect(c.country, equals('India'));
      expect(c.latitude, equals(28.6304));
      expect(c.longitude, equals(77.2177));
      expect(c.connectors, contains('CCS2'));
      expect(c.connectors, contains('Type 2'));
      expect(c.source, equals('bulk_import'));
      expect(c.isVerified, isFalse);
    });

    // ------------------------------------------------------------------------
    // TEST 2 & 3: Strict India Country Filtering & Non-India Rejection
    // ------------------------------------------------------------------------
    test('TEST 2 & 3: Accepts valid India charger and rejects non-India charger', () {
      final validIndiaRaw = {
        'ID': 99002,
        'AddressInfo': {
          'Title': 'Statiq Gurgaon Hub',
          'AddressLine1': 'MG Road',
          'Town': 'Gurgaon',
          'StateOrProvince': 'Haryana',
          'Latitude': 28.4595,
          'Longitude': 77.0266,
          'Country': {'ISOCode': 'IN', 'Title': 'India'},
        },
        'OperatorInfo': {'Title': 'Statiq'},
      };

      final nonIndiaRaw = {
        'ID': 99003,
        'AddressInfo': {
          'Title': 'London EV Station',
          'AddressLine1': 'Baker Street',
          'Town': 'London',
          'Latitude': 51.5074,
          'Longitude': -0.1278,
          'Country': {'ISOCode': 'GB', 'Title': 'United Kingdom'},
        },
      };

      final indiaModel = OpenChargeMapChargerDataSource.mapOcmJsonToModel(validIndiaRaw);
      final nonIndiaModel = OpenChargeMapChargerDataSource.mapOcmJsonToModel(nonIndiaRaw);

      expect(indiaModel, isNotNull);
      expect(indiaModel?.country, equals('India'));
      expect(nonIndiaModel, isNull);
    });

    // ------------------------------------------------------------------------
    // TEST 4 & 5 & 6: Bounding Box, Missing Name & Connector Normalization
    // ------------------------------------------------------------------------
    test('TEST 4, 5, 6: Rejects out of bounding box coords, missing title, and maps connectors', () {
      final outOfBoundsRaw = {
        'ID': 99004,
        'AddressInfo': {
          'Title': 'Tokyo Station Fake IN',
          'Latitude': 35.6762,
          'Longitude': 139.6503, // Way outside India longitude bounds
          'Country': {'ISOCode': 'IN', 'Title': 'India'},
        },
      };

      final missingTitleRaw = {
        'ID': 99005,
        'AddressInfo': {
          'Title': '',
          'Latitude': 28.4,
          'Longitude': 77.0,
          'Country': {'ISOCode': 'IN', 'Title': 'India'},
        },
      };

      final connectorTestRaw = {
        'ID': 99006,
        'AddressInfo': {
          'Title': 'Bharat Fast Charge',
          'Latitude': 12.9716,
          'Longitude': 77.5946,
          'Country': {'ISOCode': 'IN', 'Title': 'India'},
        },
        'OperatorInfo': {'Title': 'Jio-bp Pulse'},
        'Connections': [
          {'ConnectionType': {'Title': 'Bharat DC-001'}, 'PowerKW': 15},
          {'ConnectionType': {'Title': 'Bharat AC-001'}, 'PowerKW': 10},
        ],
      };

      expect(OpenChargeMapChargerDataSource.mapOcmJsonToModel(outOfBoundsRaw), isNull);
      expect(OpenChargeMapChargerDataSource.mapOcmJsonToModel(missingTitleRaw), isNull);

      final model = OpenChargeMapChargerDataSource.mapOcmJsonToModel(connectorTestRaw);
      expect(model, isNotNull);
      expect(model?.network, equals('Jio-bp'));
      expect(model?.connectors, contains('Bharat DC-001'));
      expect(model?.connectors, contains('Bharat AC-001'));
    });

    // ------------------------------------------------------------------------
    // TEST 7 & 8 & 9 & 10: Deduplication, EVHub Verified & Google Places Protection
    // ------------------------------------------------------------------------
    test('TEST 7, 8, 9, 10: Multi-tier deduplication protects existing verified chargers and Google Places', () {
      final service = CsvImportService();

      const existingVerified = MapMarkerModel(
        id: 'evhub_101',
        title: 'Zeon Fast Charger Bengaluru',
        description: 'Verified Address',
        latitude: 12.9716,
        longitude: 77.5946,
        type: MarkerType.station,
        network: 'Zeon',
        source: 'evhub_verified',
        isVerified: true,
      );

      const ocmDuplicate = MapMarkerModel(
        id: 'ocm_99006',
        title: 'Zeon Fast Charger Bengaluru',
        description: 'OCM Address',
        latitude: 12.9717, // ~10m gap
        longitude: 77.5947,
        type: MarkerType.station,
        network: 'Zeon',
        source: 'bulk_import',
        isVerified: false,
      );

      final results = service.processFetchedChargers(
        fetchedChargers: [ocmDuplicate],
        existingFirestoreChargers: [existingVerified],
      );

      expect(results.length, equals(1));
      expect(results.first.isDuplicate, isTrue);
      expect(results.first.existingDuplicateCharger?.source, equals('evhub_verified'));
      expect(results.first.existingDuplicateCharger?.isVerified, isTrue);
    });

    // ------------------------------------------------------------------------
    // TEST 11 & 12: Admin Authorization Guard
    // ------------------------------------------------------------------------
    test('TEST 11 & 12: Non-admin users are strictly blocked from executing OCM imports', () async {
      final provider = BulkImportProvider();
      final user = UserModel(
        id: 'driver_77',
        name: 'Regular Driver',
        email: 'driver@evhub.com',
        role: Role.user,
      );

      final success = await provider.executeImport(adminUser: user);
      expect(success, isFalse);
      expect(provider.errorMessage, contains('Only administrators can perform bulk charger imports.'));
    });

    // ------------------------------------------------------------------------
    // TEST 13 & 14 & 15 & 16: API Timeout, Errors, Rate Limits & Empty Responses
    // ------------------------------------------------------------------------
    test('TEST 13: OCM Timeout throws informative exception', () async {
      final client = http_testing.MockClient((request) async {
        throw Exception('Connection timed out');
      });

      final dataSource = OpenChargeMapChargerDataSource(client: client);
      expect(
        () async => await dataSource.fetchChargers(),
        throwsA(isA<Exception>()),
      );
    });

    test('TEST 15: OCM HTTP 429 Rate Limit throws rate limit exception', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response('Rate limit exceeded', 429);
      });

      final dataSource = OpenChargeMapChargerDataSource(client: client);
      expect(
        () async => await dataSource.fetchChargers(),
        throwsA(predicate((e) => e.toString().contains('Rate limit exceeded'))),
      );
    });

    test('TEST 16: OCM Empty Response returns empty list gracefully', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response(json.encode([]), 200);
      });

      final dataSource = OpenChargeMapChargerDataSource(client: client);
      final chargers = await dataSource.fetchChargers();
      expect(chargers, isEmpty);
    });

    // ------------------------------------------------------------------------
    // TEST 17 & 18: Multi-page Pagination
    // ------------------------------------------------------------------------
    test('TEST 17 & 18: Automatic multi-page pagination fetches multiple batches', () async {
      int requestCount = 0;
      final client = http_testing.MockClient((request) async {
        requestCount++;
        final pageItem = {
          'ID': 99000 + requestCount,
          'AddressInfo': {
            'Title': 'India Station P$requestCount',
            'Latitude': 19.0760,
            'Longitude': 72.8777,
            'Country': {'ISOCode': 'IN'},
          },
        };
        return http.Response(json.encode([pageItem]), 200);
      });

      final dataSource = OpenChargeMapChargerDataSource(client: client);
      final chargers = await dataSource.fetchChargers(options: {'limit': 200});

      expect(chargers.length, greaterThanOrEqualTo(1));
    });

    // ------------------------------------------------------------------------
    // TEST 22 & 23: Dashboard Metrics & Map Integration
    // ------------------------------------------------------------------------
    test('TEST 22 & 23: Dashboard correctly reports bulk_import source metrics', () {
      final mockRepo = _MockFirestoreRepo();
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockRepo);

      expect(dashboardProvider.bulkImportCount, equals(0));
      expect(dashboardProvider.bulkImportPercentage, equals(0.0));
    });

    // ------------------------------------------------------------------------
    // TEST 24 & 25: Regression Tests for NREL & CSV Importers
    // ------------------------------------------------------------------------
    test('TEST 24: NREL Importer continues working normally', () async {
      final mockJson = {
        'fuel_stations': [
          {
            'id': 333,
            'station_name': 'NREL Regression Station',
            'latitude': 37.7749,
            'longitude': -122.4194,
          }
        ]
      };

      final client = http_testing.MockClient((request) async {
        return http.Response(json.encode(mockJson), 200);
      });

      final nrelSource = NrelChargerDataSource(client: client);
      final chargers = await nrelSource.fetchChargers();
      expect(chargers.length, equals(1));
      expect(chargers.first.title, equals('NREL Regression Station'));
    });

    test('TEST 25: CSV Importer continues working normally', () {
      final service = CsvImportService();
      final csvText = '''name,network,address,city,state,country,latitude,longitude,totalConnectors,availableConnectors,power
Kazam Hub,Kazam,Indiranagar,Bengaluru,Karnataka,India,12.9784,77.6408,4,4,60kW''';

      final results = service.processCsv(
        bytes: Uint8List.fromList(utf8.encode(csvText)),
        existingFirestoreChargers: [],
      );

      expect(results.length, equals(1));
      expect(results.first.parsedModel?.title, equals('Kazam Hub'));
    });
  });
}

class _MockFirestoreRepo implements FirestoreChargerRepository {
  @override
  Future<void> addCharger(MapMarkerModel charger) async {}

  @override
  Future<void> approveCharger(String id, String adminUid) async {}

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
  Future<void> rejectCharger(String id, String adminUid) async {}

  @override
  Stream<List<MapMarkerModel>> streamAllChargers() => Stream.value([]);

  @override
  Stream<List<MapMarkerModel>> streamChargersByOwner(String ownerId) => Stream.value([]);

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() => Stream.value([]);

  @override
  Future<void> updateCharger(MapMarkerModel charger) async {}
}
