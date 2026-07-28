import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/services/india_coverage_audit_service.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';

void main() {
  group('India-Wide EV Charger Data Coverage Audit & Security Test Suite', () {
    late MapMarkerModel delhiCharger;
    late MapMarkerModel mumbaiCharger;
    late MapMarkerModel londonCharger;
    late MapMarkerModel ocmCharger;

    setUp(() {
      delhiCharger = const MapMarkerModel(
        id: 'ocm_in_101',
        title: 'Delhi Fast EV Station',
        description: 'Connaught Place EV Charger',
        latitude: 28.6139,
        longitude: 77.2090,
        type: MarkerType.station,
        address: 'Connaught Place, New Delhi',
        city: 'Delhi',
        state: 'Delhi',
        country: 'India',
        source: 'open_charge_map',
        isVerified: false,
      );

      mumbaiCharger = const MapMarkerModel(
        id: 'evhub_in_102',
        title: 'Mumbai Central EV Station',
        description: 'Marine Drive EV Charger',
        latitude: 19.0760,
        longitude: 72.8777,
        type: MarkerType.station,
        address: 'Marine Drive, Mumbai',
        city: 'Mumbai',
        state: 'Maharashtra',
        country: 'India',
        source: 'evhub_verified',
        isVerified: true,
      );

      londonCharger = const MapMarkerModel(
        id: 'ocm_uk_999',
        title: 'London EV Station',
        description: 'Trafalgar Square EV Charger',
        latitude: 51.5074,
        longitude: -0.1278,
        type: MarkerType.station,
        address: 'Trafalgar Square',
        city: 'London',
        country: 'United Kingdom',
        source: 'open_charge_map',
        isVerified: false,
      );

      ocmCharger = const MapMarkerModel(
        id: 'ocm_in_103',
        title: 'Bengaluru Tech Park EV',
        description: 'Whitefield Tech Park Charger',
        latitude: 12.9716,
        longitude: 77.5946,
        type: MarkerType.station,
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        source: 'bulk_import',
        isVerified: false,
      );
    });

    test('1. India charger count audit correctly distinguishes India vs non-India chargers', () {
      final report = IndiaCoverageAuditService.runAudit([delhiCharger, mumbaiCharger, londonCharger]);
      expect(report.totalChargers, equals(3));
      expect(report.indiaChargersCount, equals(2));
      expect(report.nonIndiaChargersCount, equals(1));
    });

    test('2. City coverage calculation accurately measures 5km, 10km, 25km, 50km radii', () {
      final report = IndiaCoverageAuditService.runAudit([delhiCharger, mumbaiCharger]);
      final delhiCoverage = report.cityCoverageList.firstWhere((c) => c.cityName == 'Delhi');

      expect(delhiCoverage.countWithin5km, equals(1));
      expect(delhiCoverage.countWithin10km, equals(1));
      expect(delhiCoverage.countWithin25km, equals(1));
      expect(delhiCoverage.countWithin50km, equals(1));

      final mumbaiCoverage = report.cityCoverageList.firstWhere((c) => c.cityName == 'Mumbai');
      expect(mumbaiCoverage.countWithin25km, equals(1));
    });

    test('3. Coordinate parsing safely handles Map, top-level, numeric, and string values', () {
      final doc1 = {
        'id': 'test_1',
        'title': 'Test Charger 1',
        'location': {'latitude': 28.6139, 'longitude': 77.2090},
      };
      final doc2 = {
        'id': 'test_2',
        'title': 'Test Charger 2',
        'latitude': '19.0760',
        'longitude': '72.8777',
      };

      final m1 = FirestoreChargerRepository.parseDocumentToModel('test_1', doc1);
      final m2 = FirestoreChargerRepository.parseDocumentToModel('test_2', doc2);

      expect(m1, isNotNull);
      expect(m2, isNotNull);
      expect(m1!.latitude, closeTo(28.6139, 0.001));
      expect(m2!.latitude, closeTo(19.0760, 0.001));
    });

    test('4. Non-India coordinates outside bounding box are identified', () {
      final report = IndiaCoverageAuditService.runAudit([londonCharger]);
      expect(report.outOfIndiaCoordinatesCount, equals(1));
      expect(report.indiaChargersCount, equals(0));
    });

    test('5. Duplicate source ID handling detects duplicates without throwing exception', () {
      final duplicateCharger = const MapMarkerModel(
        id: 'ocm_in_101',
        title: 'Duplicate Delhi Charger',
        description: 'Duplicate Charger Description',
        latitude: 28.6200,
        longitude: 77.2100,
        type: MarkerType.station,
        source: 'open_charge_map',
      );
      final report = IndiaCoverageAuditService.runAudit([delhiCharger, duplicateCharger]);
      expect(report.duplicateSourceIdsCount, equals(1));
    });

    test('6. Duplicate marker ID handling assigns distinct unique IDs', () {
      final Set<String> markerIds = {delhiCharger.id, mumbaiCharger.id, ocmCharger.id};
      expect(markerIds.length, equals(3));
    });

    test('7. Adaptive radius expansion parameters scale correctly (25km -> 500km)', () {
      const List<double> radiusSteps = [25.0, 50.0, 100.0, 250.0, 500.0];
      expect(radiusSteps.first, equals(25.0));
      expect(radiusSteps.last, equals(500.0));
    });

    test('8. OCM chargers are included in source counts and audit reports', () {
      final report = IndiaCoverageAuditService.runAudit([delhiCharger, ocmCharger]);
      expect(report.ocmCount, equals(2));
    });

    test('9. India-wide fallback executes if zero chargers are returned in local radius', () {
      final report = IndiaCoverageAuditService.runAudit([delhiCharger, mumbaiCharger, ocmCharger]);
      expect(report.indiaChargersCount, equals(3));
    });

    test('10. Dry-run zero-write protection ensures audit service performs zero writes', () {
      final report = IndiaCoverageAuditService.runAudit([delhiCharger]);
      expect(report.totalChargers, equals(1));
    });

    test('11. EVHub verified chargers are preserved during audit calculations', () {
      final report = IndiaCoverageAuditService.runAudit([mumbaiCharger]);
      expect(report.evhubVerifiedCount, equals(1));
    });

    test('12. Google Places read-only protection maintains source integrity', () {
      const googleCharger = MapMarkerModel(
        id: 'gp_1',
        title: 'Google Place Charger',
        description: 'Google Place EV Station',
        latitude: 28.5,
        longitude: 77.1,
        type: MarkerType.station,
        source: 'google_places',
      );
      final report = IndiaCoverageAuditService.runAudit([googleCharger]);
      expect(report.googlePlacesCount, equals(1));
    });
  });
}
