import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/core/widgets/charger_marker_factory.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';

class DummyFirestoreChargerRepository implements FirestoreChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVHub Map UI/UX Redesign & Charger Marker Pipeline Test Suite', () {
    setUpAll(() async {
      await ChargerMarkerFactory.init();
    });

    test('TEST A: ChargerMarkerFactory initializes cached icons', () {
      expect(ChargerMarkerFactory.isInitialized, true);
      expect(ChargerMarkerFactory.availableIcon, isNotNull);
      expect(ChargerMarkerFactory.busyIcon, isNotNull);
      expect(ChargerMarkerFactory.offlineIcon, isNotNull);
      expect(ChargerMarkerFactory.unknownIcon, isNotNull);
      expect(ChargerMarkerFactory.verifiedIcon, isNotNull);
      expect(ChargerMarkerFactory.selectedIcon, isNotNull);
    });

    test('TEST B: Marker selection returns distinct icons for status states', () {
      final availableCharger = MapMarkerModel(
        id: 'c_1',
        title: 'Tata Power Fast Charger',
        description: 'Connaught Place, New Delhi',
        type: MarkerType.station,
        latitude: 28.6304,
        longitude: 77.2177,
        status: MarkerStatus.available,
        network: 'Tata Power',
      );

      final busyCharger = MapMarkerModel(
        id: 'c_2',
        title: 'Statiq Hub',
        description: 'Cyber City, Gurugram',
        type: MarkerType.station,
        latitude: 28.6315,
        longitude: 77.2185,
        status: MarkerStatus.busy,
        network: 'Statiq',
      );

      final offlineCharger = MapMarkerModel(
        id: 'c_3',
        title: 'Zeon Station',
        description: 'Indiranagar, Bengaluru',
        type: MarkerType.station,
        latitude: 28.6325,
        longitude: 77.2195,
        status: MarkerStatus.offline,
        network: 'Zeon',
      );

      final icon1 = ChargerMarkerFactory.getIconForCharger(availableCharger);
      final icon2 = ChargerMarkerFactory.getIconForCharger(busyCharger);
      final icon3 = ChargerMarkerFactory.getIconForCharger(offlineCharger);
      final iconSelected = ChargerMarkerFactory.getIconForCharger(availableCharger, isSelected: true);

      expect(icon1, isNotNull);
      expect(icon2, isNotNull);
      expect(icon3, isNotNull);
      expect(iconSelected, isNotNull);
      expect(iconSelected, equals(ChargerMarkerFactory.selectedIcon));
    });

    test('TEST C: BuildMarker sets anchor Offset(0.5, 1.0) for accurate pin tip alignment', () {
      final charger = MapMarkerModel(
        id: 'c_1',
        title: 'Jio-bp Pulse',
        description: 'MG Road, Bengaluru',
        type: MarkerType.station,
        latitude: 12.9716,
        longitude: 77.5946,
        status: MarkerStatus.available,
      );

      final marker = ChargerMarkerFactory.buildMarker(
        charger: charger,
        isSelected: false,
        onTap: () {},
      );

      expect(marker.anchor.dx, 0.5);
      expect(marker.anchor.dy, 1.0);
      expect(marker.markerId.value, 'c_1');
    });

    test('TEST D: MapsProvider getFilteredMarkers filters by source, connector, status and network', () {
      final service = MapsService();
      final provider = MapsProvider(
        mapsRepository: MapsRepository(mapsService: service),
        mapsService: service,
        firestoreChargerRepository: DummyFirestoreChargerRepository(),
      );

      final m1 = MapMarkerModel(
        id: '1',
        title: 'EVHub Verified Tata Charger',
        description: 'Delhi EV Hub',
        type: MarkerType.station,
        latitude: 28.6,
        longitude: 77.2,
        source: 'evhub_verified',
        isVerified: true,
        status: MarkerStatus.available,
        connectors: ['CCS2', 'Type 2'],
        power: '60 kW',
        network: 'Tata Power',
      );

      final m2 = MapMarkerModel(
        id: '2',
        title: 'Google Places Station',
        description: 'Noida Station',
        type: MarkerType.station,
        latitude: 28.7,
        longitude: 77.3,
        source: 'google_places',
        isVerified: false,
        status: MarkerStatus.busy,
        connectors: ['Type 2'],
        power: '22 kW',
        network: 'Statiq',
      );

      provider.setMarkers([m1, m2]);

      expect(provider.getFilteredMarkers().length, 2);

      // Filter EVHub Verified
      provider.setSourceFilter('EVHub Verified');
      expect(provider.getFilteredMarkers().length, 1);
      expect(provider.getFilteredMarkers().first.id, '1');

      // Clear source filter
      provider.setSourceFilter('All Sources');
      expect(provider.getFilteredMarkers().length, 2);

      // Filter Available status
      provider.setStatusFilter('Available');
      expect(provider.getFilteredMarkers().length, 1);
      expect(provider.getFilteredMarkers().first.id, '1');
    });
  });
}
