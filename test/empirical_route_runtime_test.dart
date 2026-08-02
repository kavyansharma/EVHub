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
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Empirical Runtime Test: Ansal Heights Sector 92 Gurugram to HUDA City Centre Gurugram', () async {
    final mapsService = MapsService();

    // 1. Geocode origin
    final originAddress = "Ansal Heights, Sector 92, Gurugram";
    final originCoords = await mapsService.getCoordinatesFromAddress(originAddress);
    print("EMPIRICAL TEST - ORIGIN GEOMETRY:");
    print("Address: $originAddress");
    print("Coordinates: ${originCoords?.latitude}, ${originCoords?.longitude}");

    expect(originCoords, isNotNull);
    expect(originCoords!.latitude, isNot(equals(0.0)));
    expect(originCoords.longitude, isNot(equals(0.0)));

    // 2. Geocode destination
    final destAddress = "HUDA City Centre, Gurugram";
    final destCoords = await mapsService.getCoordinatesFromAddress(destAddress);
    print("EMPIRICAL TEST - DESTINATION GEOMETRY:");
    print("Address: $destAddress");
    print("Coordinates: ${destCoords?.latitude}, ${destCoords?.longitude}");

    expect(destCoords, isNotNull);
    expect(destCoords!.latitude, isNot(equals(0.0)));
    expect(destCoords.longitude, isNot(equals(0.0)));

    // 3. Directions calculation
    final directions = await mapsService.getDirections(originCoords, destCoords);
    print("EMPIRICAL TEST - ROAD ROUTING:");
    print("Directions success: ${directions != null}");

    if (directions != null) {
      final String distanceText = directions['distance'] as String;
      final String durationText = directions['duration'] as String;
      final List<LatLng> points = directions['points'] as List<LatLng>;

      print("Route distance: $distanceText");
      print("Route duration: $durationText");
      print("Polyline points count: ${points.length}");

      expect(points.length, greaterThan(1));

      // 4. Charger corridor search & travel order sorting
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: MockFirestoreRepoForEmpiricalTest(),
        mapsService: mapsService,
      );
      final corridorChargers = await hybridRepo.searchRouteCorridorChargers(
        polylinePoints: points,
        corridorRadiusKm: 10.0,
      );

      print("EMPIRICAL TEST - CORRIDOR CHARGERS:");
      print("Chargers count: ${corridorChargers.length}");

      for (int i = 0; i < corridorChargers.length; i++) {
        final c = corridorChargers[i];
        print("  [$i] Name: ${c.title}");
        print("      Address: ${c.displayAddress}");
        print("      Speed: ${c.displayPower} (${c.powerType})");
        print("      Connectors: ${c.displayConnectors}");
        print("      Price: ${c.pricePerKwh}");
        print("      Status: ${c.computedStatus.name.toUpperCase()}");
        print("      From Start: ${c.routeDistanceFromOriginKm?.toStringAsFixed(1)} km");
        print("      To Dest: ${c.routeDistanceToDestKm?.toStringAsFixed(1)} km");
      }

      if (corridorChargers.length > 1) {
        final firstProg = corridorChargers[0].routeDistanceFromOriginKm ?? 0.0;
        final secondProg = corridorChargers[1].routeDistanceFromOriginKm ?? 0.0;
        expect(firstProg, lessThanOrEqualTo(secondProg));
      }
    }
  });
}
