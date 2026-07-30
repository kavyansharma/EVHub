import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';

void main() {
  group('EV Charger Marker Pipeline End-to-End Tests', () {
    test('1 & 2 & 3: Document to model supports all coordinate formats, fields, and unique docId', () {
      final doc1Map = {
        'id': 'charger_duplicate_id',
        'name': 'Tata Power Bengaluru Hub',
        'address': 'MG Road, Bengaluru',
        'network': 'Tata Power',
        'location': const GeoPoint(12.9716, 77.5946),
        'status': 'available',
        'power': '60kW',
        'connectorTypes': ['CCS2'],
        'isVerified': false,
        'verificationStatus': 'unverified',
      };

      final doc2Map = {
        'id': 'charger_duplicate_id', // duplicate data id
        'title': 'Statiq Delhi Charging Hub',
        'description': 'Connaught Place, New Delhi',
        'network': 'Statiq',
        'latitude': '28.6304', // String format
        'longitude': '77.2177',
        'status': 'busy',
        'power': '120kW',
        'connectors': ['Type 2', 'CCS2'],
      };

      final doc3ReversedMap = {
        'title': 'Zeon Fast Charger Jaipur',
        'address': 'MI Road, Jaipur',
        'network': 'Zeon',
        'latitude': 75.7873, // Reversed lat/lng in India dataset (lng stored in lat)
        'longitude': 26.9124, // lat stored in lng
        'status': 'available',
        'power': '150kW',
      };

      final model1 = FirestoreChargerRepository.parseDocumentToModel('doc_id_101', doc1Map);
      final model2 = FirestoreChargerRepository.parseDocumentToModel('doc_id_102', doc2Map);
      final model3 = FirestoreChargerRepository.parseDocumentToModel('doc_id_103', doc3ReversedMap);

      expect(model1, isNotNull);
      expect(model1!.id, equals('doc_id_101')); // Unique docId used
      expect(model1.title, equals('Tata Power Bengaluru Hub'));
      expect(model1.latitude, equals(12.9716));
      expect(model1.longitude, equals(77.5946));

      expect(model2, isNotNull);
      expect(model2!.id, equals('doc_id_102')); // Unique docId used
      expect(model2.title, equals('Statiq Delhi Charging Hub'));
      expect(model2.latitude, equals(28.6304));
      expect(model2.longitude, equals(77.2177));

      expect(model3, isNotNull);
      expect(model3!.id, equals('doc_id_103'));
      // Reversed coordinates swapped correctly: lat=26.9124, lng=75.7873
      expect(model3.latitude, equals(26.9124));
      expect(model3.longitude, equals(75.7873));
    });

    test('TEST A — CURRENT LOCATION: Nearby chargers returned correctly', () async {
      final delhiCharger = const MapMarkerModel(
        id: 'delhi_1',
        title: 'Delhi Hub',
        description: 'New Delhi',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
      );

      final mockFsRepo = MockFirestoreRepo([delhiCharger]);
      final mockMapsService = MockMapsRepoService();
      final hybridRepo = HybridChargerRepository(firestoreRepository: mockFsRepo, mapsService: mockMapsService);

      final results = await hybridRepo.searchNearbyChargers(
        latitude: 28.6304,
        longitude: 77.2177,
        initialRadiusKm: 25.0,
      );

      expect(results.length, equals(1));
      expect(results.first.title, equals('Delhi Hub'));
    });

    test('TEST B — SEARCH LOCATION: Bengaluru search returns Bengaluru chargers', () async {
      final blrCharger = const MapMarkerModel(
        id: 'blr_1',
        title: 'Bengaluru Station',
        description: 'MG Road',
        latitude: 12.9716,
        longitude: 77.5946,
        type: MarkerType.station,
      );

      final mockFsRepo = MockFirestoreRepo([blrCharger]);
      final mockMapsService = MockMapsRepoService();
      final hybridRepo = HybridChargerRepository(firestoreRepository: mockFsRepo, mapsService: mockMapsService);

      final results = await hybridRepo.searchNearbyChargers(
        latitude: 12.9716,
        longitude: 77.5946,
        initialRadiusKm: 25.0,
      );

      expect(results.length, equals(1));
      expect(results.first.title, equals('Bengaluru Station'));
    });

    test('TEST C — ROUTE: Delhi to Jaipur polyline corridor (10 km) filters chargers', () async {
      final corridorCharger = const MapMarkerModel(
        id: 'corridor_1',
        title: 'Gurugram Highway Charger',
        description: 'NH 48',
        latitude: 28.4595,
        longitude: 77.0266,
        type: MarkerType.station,
      );

      final farCharger = const MapMarkerModel(
        id: 'far_1',
        title: 'Kolkata Charger',
        description: 'Kolkata',
        latitude: 22.5726,
        longitude: 88.3639,
        type: MarkerType.station,
      );

      final mockFsRepo = MockFirestoreRepo([corridorCharger, farCharger]);
      final hybridRepo = HybridChargerRepository(firestoreRepository: mockFsRepo);

      final routePoints = [
        const LatLng(28.6139, 77.2090), // Delhi
        const LatLng(28.4595, 77.0266), // Gurugram
        const LatLng(26.9124, 75.7873), // Jaipur
      ];

      final corridorResults = await hybridRepo.searchRouteCorridorChargers(
        polylinePoints: routePoints,
        corridorRadiusKm: 10.0,
      );

      expect(corridorResults.length, equals(1));
      expect(corridorResults.first.id, equals('corridor_1'));
    });
  });
}

class MockFirestoreRepo implements FirestoreChargerRepository {
  final List<MapMarkerModel> chargers;
  MockFirestoreRepo(this.chargers);

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async {
    return chargers;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsRepoService implements MapsService {
  @override
  Future<List<MapMarkerModel>> getNearbyStations(double lat, double lng, double radiusKm) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
