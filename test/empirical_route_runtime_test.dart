// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/models/map_marker_model.dart';

class MockFirestoreRepoForEmpiricalTest implements FirestoreChargerRepository {
  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async {
    return const [
      MapMarkerModel(
        id: 'charger_gurugram_1',
        title: 'Tata Power Fast Charger Sector 86',
        description: 'Sector 86, Gurugram',
        address: 'Sector 86 Main Rd, Gurugram, Haryana',
        latitude: 28.4050,
        longitude: 76.9450,
        type: MarkerType.station,
        power: '60 kW',
        powerType: 'Fast',
        connectors: ['CCS2', 'Type 2'],
        price: '₹18/kWh',
        source: 'evhub_verified',
      ),
      MapMarkerModel(
        id: 'charger_gurugram_2',
        title: 'Statiq Hub HUDA City Centre',
        description: 'HUDA City Centre Metro Station',
        address: 'HUDA City Centre Metro Station, Sector 29, Gurugram',
        latitude: 28.4590,
        longitude: 77.0720,
        type: MarkerType.station,
        power: '120 kW',
        powerType: 'Ultra Fast',
        connectors: ['CCS2'],
        price: '₹21/kWh',
        source: 'evhub_verified',
      ),
      MapMarkerModel(
        id: 'charger_chennai_1',
        title: 'Kalyan Grand Business Hotel Charger',
        description: 'Vandalur, Chennai',
        address: 'GST Road, Next to Vandalur Zoo, Chennai',
        latitude: 12.8893,
        longitude: 80.0815,
        type: MarkerType.station,
        power: '24 kW',
        powerType: 'Fast',
        connectors: ['Type 2', 'CCS2'],
        price: '₹18/kWh',
        source: 'evhub_verified',
      ),
      MapMarkerModel(
        id: 'charger_far_away',
        title: 'Far Off-Route Charger',
        description: 'Remote Location',
        address: 'Outskirts, Far Away',
        latitude: 15.0000,
        longitude: 75.0000,
        type: MarkerType.station,
        power: '50 kW',
        powerType: 'Fast',
        connectors: ['CCS2'],
        price: '₹15/kWh',
        source: 'evhub_verified',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final mapsService = MapsService();
  final hybridRepo = HybridChargerRepository(
    firestoreRepository: MockFirestoreRepoForEmpiricalTest(),
    mapsService: mapsService,
  );

  test('Test A: Ansal Heights, Sector 92, Gurugram -> HUDA City Centre, Gurugram', () async {
    final originAddress = "Ansal Heights, Sector 92, Gurugram";
    final destAddress = "HUDA City Centre, Gurugram";

    final originCoords = await mapsService.getCoordinatesFromAddress(originAddress);
    final destCoords = await mapsService.getCoordinatesFromAddress(destAddress);

    expect(originCoords, isNotNull);
    expect(destCoords, isNotNull);

    final directions = await mapsService.getDirections(originCoords!, destCoords!);
    expect(directions, isNotNull);

    final points = directions!['points'] as List<LatLng>;
    final corridorChargers = await hybridRepo.searchRouteCorridorChargers(
      polylinePoints: points,
      corridorRadiusKm: 10.0,
    );

    print("[TRIP_DEBUG] Test A Final Chargers: ${corridorChargers.length}");
    expect(corridorChargers.length, greaterThanOrEqualTo(1));
  });

  test('Test B: SRM University, Chennai -> Chennai Airport', () async {
    final originAddress = "SRM University, Chennai";
    final destAddress = "Chennai Airport";

    final originCoords = await mapsService.getCoordinatesFromAddress(originAddress);
    final destCoords = await mapsService.getCoordinatesFromAddress(destAddress);

    expect(originCoords, isNotNull);
    expect(destCoords, isNotNull);

    final directions = await mapsService.getDirections(originCoords!, destCoords!);
    expect(directions, isNotNull);

    final points = directions!['points'] as List<LatLng>;
    final corridorChargers = await hybridRepo.searchRouteCorridorChargers(
      polylinePoints: points,
      corridorRadiusKm: 10.0,
    );

    print("[TRIP_DEBUG] Test B Final Chargers: ${corridorChargers.length}");
    expect(corridorChargers.length, greaterThanOrEqualTo(1));
  });

  test('Test C: Route with at least one known charger directly along the route', () async {
    final originCoords = const LatLng(12.8398, 80.0544); // SRM Kattankulathur
    final destCoords = const LatLng(12.9863, 80.1752);   // Chennai Airport

    final directions = await mapsService.getDirections(originCoords, destCoords);
    expect(directions, isNotNull);

    final points = directions!['points'] as List<LatLng>;
    final corridorChargers = await hybridRepo.searchRouteCorridorChargers(
      polylinePoints: points,
      corridorRadiusKm: 10.0,
    );

    print("[TRIP_DEBUG] Test C Final Chargers: ${corridorChargers.length}");
    expect(corridorChargers.any((c) => c.title.contains('Kalyan Grand')), isTrue);
  });
}
