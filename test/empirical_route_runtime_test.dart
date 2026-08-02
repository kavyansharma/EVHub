// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/services/maps_service.dart';

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
    }
  });
}
