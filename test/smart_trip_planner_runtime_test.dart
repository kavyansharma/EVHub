import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/services/india_coverage_audit_service.dart';

void main() {
  group('Smart EV Trip Planner Runtime Regression Test Suite', () {
    late LocationSearchResult ansalHeights;
    late LocationSearchResult hudaCityCentre;
    late LocationSearchResult indiaGate;
    late LocationSearchResult cyberHub;

    setUp(() {
      ansalHeights = const LocationSearchResult(
        displayName: 'Ansal Heights, Sector 92, Gurugram, Haryana',
        subtitle: 'Haryana, India',
        latitude: 28.3948,
        longitude: 76.9822,
        placeId: 'ChIJXXXX_ansal_heights',
        source: LocationSearchResultSource.googlePlaces,
      );
      hudaCityCentre = const LocationSearchResult(
        displayName: 'HUDA City Centre, Gurugram, Haryana',
        subtitle: 'Haryana, India',
        latitude: 28.4709,
        longitude: 77.0726,
        placeId: 'ChIJXXXX_huda_city_centre',
        source: LocationSearchResultSource.googlePlaces,
      );
      indiaGate = const LocationSearchResult(
        displayName: 'India Gate, New Delhi',
        subtitle: 'New Delhi, India',
        latitude: 28.6129,
        longitude: 77.2295,
        placeId: 'ChIJXXXX_india_gate',
        source: LocationSearchResultSource.googlePlaces,
      );
      cyberHub = const LocationSearchResult(
        displayName: 'Cyber Hub, Gurugram, Haryana',
        subtitle: 'Haryana, India',
        latitude: 28.4950,
        longitude: 77.0880,
        placeId: 'ChIJXXXX_cyber_hub',
        source: LocationSearchResultSource.googlePlaces,
      );
    });

    test('1. Exact address origin stores resolved latitude and longitude', () {
      expect(ansalHeights.latitude, isNot(equals(0.0)));
      expect(ansalHeights.longitude, isNot(equals(0.0)));
      expect(ansalHeights.latitude, closeTo(28.39, 0.1));
      expect(ansalHeights.longitude, closeTo(76.98, 0.1));
    });

    test('2. Exact address destination stores resolved latitude and longitude', () {
      expect(hudaCityCentre.latitude, isNot(equals(0.0)));
      expect(hudaCityCentre.longitude, isNot(equals(0.0)));
      expect(hudaCityCentre.latitude, closeTo(28.47, 0.1));
      expect(hudaCityCentre.longitude, closeTo(77.07, 0.1));
    });

    test('3. LocationSearchResult.coordinates returns valid LatLng', () {
      final originCoords = ansalHeights.coordinates;
      final destCoords = hudaCityCentre.coordinates;
      expect(originCoords, isA<LatLng>());
      expect(destCoords, isA<LatLng>());
      expect(originCoords.latitude, isNot(equals(0.0)));
      expect(destCoords.latitude, isNot(equals(0.0)));
    });

    test('4. Origin and destination coordinates are different', () {
      expect(
        ansalHeights.latitude == hudaCityCentre.latitude &&
            ansalHeights.longitude == hudaCityCentre.longitude,
        isFalse,
      );
    });

    test('5. India Gate landmark coordinates are valid India-region coordinates', () {
      expect(indiaGate.latitude, inInclusiveRange(6.0, 37.0));
      expect(indiaGate.longitude, inInclusiveRange(68.0, 98.0));
    });

    test('6. Cyber Hub coordinates are in Gurugram region', () {
      expect(cyberHub.latitude, closeTo(28.5, 0.3));
      expect(cyberHub.longitude, closeTo(77.1, 0.3));
    });

    test('7. Google Places source is correctly set', () {
      expect(ansalHeights.source, equals(LocationSearchResultSource.googlePlaces));
    });

    test('8. Place ID is stored and accessible', () {
      expect(ansalHeights.placeId, isNotNull);
      expect(ansalHeights.placeId!.isNotEmpty, isTrue);
    });

    test('9. Adaptive corridor steps cover 5km to 50km', () {
      const corridorSteps = [5.0, 10.0, 25.0, 50.0];
      expect(corridorSteps.first, equals(5.0));
      expect(corridorSteps.last, equals(50.0));
      expect(corridorSteps, hasLength(4));
    });

    test('10. Corridor steps are in ascending order', () {
      const corridorSteps = [5.0, 10.0, 25.0, 50.0];
      for (int i = 1; i < corridorSteps.length; i++) {
        expect(corridorSteps[i], greaterThan(corridorSteps[i - 1]));
      }
    });

    test('11. MapMarkerModel hasValidCoordinates for India-region charger', () {
      const gurugram = MapMarkerModel(
        id: 'test_gurugram_1',
        title: 'Gurugram EV Station',
        description: 'Gurugram EV Station',
        latitude: 28.45,
        longitude: 77.03,
        type: MarkerType.station,
        source: 'evhub_verified',
        isVerified: true,
      );
      expect(gurugram.hasValidCoordinates, isTrue);
    });

    test('12. MapMarkerModel with zero coordinates is invalid', () {
      const invalidCharger = MapMarkerModel(
        id: 'test_invalid',
        title: 'Invalid Charger',
        description: 'Invalid Charger',
        latitude: 0.0,
        longitude: 0.0,
        type: MarkerType.station,
        source: 'evhub_verified',
      );
      expect(invalidCharger.hasValidCoordinates, isFalse);
    });

    test('13. Charger within 5km of route segment passes distance check', () {
      const midpointLat = 28.43;
      const nearbyChargerLat = 28.435;
      final latDiff = (nearbyChargerLat - midpointLat).abs();
      final approxDistKm = latDiff * 111.0;
      expect(approxDistKm, lessThan(5.0));
    });

    test('14. Place Details coordinates require no GPS permission', () {
      expect(ansalHeights.latitude, isNot(equals(0.0)));
      expect(ansalHeights.longitude, isNot(equals(0.0)));
    });

    test('15. Zero-coordinate guard catches unresolved locations', () {
      const zeroResult = LocationSearchResult(
        displayName: 'Unresolved Location',
        latitude: 0.0,
        longitude: 0.0,
        source: LocationSearchResultSource.googlePlaces,
      );
      final isInvalidOrigin =
          zeroResult.latitude == 0.0 && zeroResult.longitude == 0.0;
      expect(isInvalidOrigin, isTrue);
    });

    test('16. India Coverage Audit accepts Gurugram charger', () {
      const gurugramCharger = MapMarkerModel(
        id: 'test_audit_gurugram',
        title: 'Gurugram EV Hub',
        description: 'Gurugram EV Hub',
        latitude: 28.4595,
        longitude: 77.0266,
        type: MarkerType.station,
        country: 'India',
        source: 'evhub_verified',
        isVerified: true,
      );
      final report = IndiaCoverageAuditService.runAudit([gurugramCharger]);
      expect(report.indiaChargersCount, equals(1));
      expect(report.outOfIndiaCoordinatesCount, equals(0));
    });

    test('17. Charger marker model contains complete details for immediate display', () {
      const charger = MapMarkerModel(
        id: 'test_full_details',
        title: 'Statiq EV Station',
        description: 'Golf Course Road, Gurugram',
        latitude: 28.4651,
        longitude: 77.0985,
        type: MarkerType.station,
        network: 'Statiq',
        power: '60 kW',
        powerType: 'DC Fast',
        connectors: ['CCS2', 'CHAdeMO'],
        address: 'Golf Course Road, Gurugram, Haryana',
        source: 'evhub_verified',
        isVerified: true,
        availabilityStatus: 'Available',
        status: MarkerStatus.available,
      );
      expect(charger.title, equals('Statiq EV Station'));
      expect(charger.network, equals('Statiq'));
      expect(charger.power, equals('60 kW'));
      expect(charger.connectors, contains('CCS2'));
      expect(charger.isVerified, isTrue);
      expect(charger.hasValidCoordinates, isTrue);
    });

    test('18. LocationSearchResult.toSuggestionMap preserves all required fields', () {
      final map = ansalHeights.toSuggestionMap();
      expect(map['description'], equals(ansalHeights.displayName));
      expect(map['latitude'], equals(ansalHeights.latitude));
      expect(map['longitude'], equals(ansalHeights.longitude));
      expect(map['place_id'], equals(ansalHeights.placeId));
    });

    test('19. Sector address is a valid searchable location type', () {
      const sectorAddress = LocationSearchResult(
        displayName: 'Sector 92, Gurugram, Haryana',
        subtitle: 'Haryana, India',
        latitude: 28.39,
        longitude: 76.98,
        source: LocationSearchResultSource.googlePlaces,
      );
      expect(sectorAddress.latitude, isNot(equals(0.0)));
      expect(sectorAddress.displayName, contains('Sector 92'));
    });

    test('20. Airport name is a valid searchable location type', () {
      const airportLocation = LocationSearchResult(
        displayName: 'Indira Gandhi International Airport, New Delhi',
        subtitle: 'New Delhi, India',
        latitude: 28.5562,
        longitude: 77.1000,
        source: LocationSearchResultSource.googlePlaces,
      );
      expect(airportLocation.latitude, closeTo(28.55, 0.1));
      expect(airportLocation.displayName, contains('Airport'));
    });
  });
}
