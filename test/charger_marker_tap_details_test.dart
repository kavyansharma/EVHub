import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';

class MockFirestoreRepoForTapTest implements FirestoreChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVHub Charger Marker Tap & Details Pipeline Test Suite', () {
    late MapsProvider mapsProvider;
    late MapsService mapsService;

    final chargerAvailable = MapMarkerModel(
      id: 'tata_cp_101',
      title: 'Tata Power Superfast Station',
      description: 'Connaught Place, New Delhi',
      type: MarkerType.station,
      latitude: 28.6304,
      longitude: 77.2177,
      status: MarkerStatus.available,
      network: 'Tata Power',
      power: '60 kW',
      connectors: ['CCS2', 'Type 2'],
      isVerified: true,
      source: 'evhub_verified',
      distanceKm: 2.4,
    );

    final chargerBusy = MapMarkerModel(
      id: 'statiq_cyber_202',
      title: 'Statiq Charging Hub',
      description: 'Cyber City, Gurugram',
      type: MarkerType.station,
      latitude: 28.4950,
      longitude: 77.0890,
      status: MarkerStatus.busy,
      network: 'Statiq',
      power: '120 kW',
      connectors: ['CCS2'],
      isVerified: false,
      source: 'google_places',
      distanceKm: 12.8,
    );

    final chargerOffline = MapMarkerModel(
      id: 'zeon_blr_303',
      title: 'Zeon Fast Charging',
      description: 'Indiranagar, Bengaluru',
      type: MarkerType.station,
      latitude: 12.9784,
      longitude: 77.6408,
      status: MarkerStatus.offline,
      network: 'Zeon',
      power: '', // Power unavailable
      connectors: [], // Connectors unavailable
      isVerified: false,
      source: 'google_places',
    );

    setUp(() {
      mapsService = MapsService();
      mapsProvider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: mapsService),
        mapsService: mapsService,
        firestoreChargerRepository: MockFirestoreRepoForTapTest(),
      );
      mapsProvider.setMarkers([chargerAvailable, chargerBusy, chargerOffline]);
    });

    test('1. Marker ID maps 1-to-1 to exact ChargerModel in memory', () {
      final marker = mapsProvider.getMarkerById('tata_cp_101');
      expect(marker, isNotNull);
      expect(marker!.title, 'Tata Power Superfast Station');
      expect(marker.network, 'Tata Power');
      expect(marker.status, MarkerStatus.available);
      expect(marker.isVerified, true);
    });

    test('2. Tapping marker calls setSelectedMarker and updates selectedMarker state immediately', () {
      expect(mapsProvider.selectedMarker, isNull);

      mapsProvider.selectMarkerById('tata_cp_101');

      expect(mapsProvider.selectedMarker, isNotNull);
      expect(mapsProvider.selectedMarker!.id, 'tata_cp_101');
      expect(mapsProvider.selectedMarker!.title, 'Tata Power Superfast Station');
    });

    test('3. Tapping multiple markers updates selected charger instantly without caching previous charger', () {
      mapsProvider.selectMarkerById('tata_cp_101');
      expect(mapsProvider.selectedMarker!.id, 'tata_cp_101');

      mapsProvider.selectMarkerById('statiq_cyber_202');
      expect(mapsProvider.selectedMarker!.id, 'statiq_cyber_202');
      expect(mapsProvider.selectedMarker!.title, 'Statiq Charging Hub');
      expect(mapsProvider.selectedMarker!.status, MarkerStatus.busy);

      mapsProvider.selectMarkerById('zeon_blr_303');
      expect(mapsProvider.selectedMarker!.id, 'zeon_blr_303');
      expect(mapsProvider.selectedMarker!.status, MarkerStatus.offline);
    });

    test('4. Missing optional fields (power, connectors, distance) does not block selectedMarker', () {
      mapsProvider.selectMarkerById('zeon_blr_303');

      final selected = mapsProvider.selectedMarker!;
      expect(selected, isNotNull);
      expect(selected.power, isEmpty);
      expect(selected.connectors, isEmpty);
      expect(selected.distanceKm, isNull);
      expect(selected.status, MarkerStatus.offline);
    });

    test('5. Deselecting marker sets selectedMarker to null without changing markers list', () {
      mapsProvider.selectMarkerById('tata_cp_101');
      expect(mapsProvider.selectedMarker, isNotNull);

      mapsProvider.setSelectedMarker(null);
      expect(mapsProvider.selectedMarker, isNull);
      expect(mapsProvider.markers.length, 3);
    });

    test('6. Search mode marker tap preserves search mode and active markers', () {
      mapsProvider.setSourceFilter('EVHub Verified');
      final filtered = mapsProvider.getFilteredMarkers();
      expect(filtered.length, 1);

      mapsProvider.selectMarkerById(filtered.first.id);
      expect(mapsProvider.selectedMarker, isNotNull);
      expect(mapsProvider.selectedSourceFilter, 'EVHub Verified');

      mapsProvider.setSelectedMarker(null);
      expect(mapsProvider.selectedSourceFilter, 'EVHub Verified');
      expect(mapsProvider.getFilteredMarkers().length, 1);
    });

    test('7. Tapping non-existent marker ID safely handles null without crashing', () {
      mapsProvider.selectMarkerById('invalid_id_999');
      expect(mapsProvider.selectedMarker, isNull);
    });
  });
}
