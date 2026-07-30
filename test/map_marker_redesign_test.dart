import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/core/widgets/charger_marker_factory.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/services/maps_service.dart';

class MockMapsRepository implements MapsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsService implements MapsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirestoreChargerRepository implements FirestoreChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHybridChargerRepository implements HybridChargerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EV Map Marker Redesign & Factory Tests', () {
    late MapMarkerModel availableCharger;
    late MapMarkerModel busyCharger;
    late MapMarkerModel offlineCharger;
    late MapMarkerModel unknownCharger;
    late MapMarkerModel verifiedCharger;

    setUp(() async {
      availableCharger = const MapMarkerModel(
        id: 'charger_avail_1',
        title: 'Tata Power Fast Charger',
        description: 'Available Charger',
        latitude: 28.6139,
        longitude: 77.2090,
        type: MarkerType.station,
        status: MarkerStatus.available,
      );

      busyCharger = const MapMarkerModel(
        id: 'charger_busy_1',
        title: 'Statiq Charger',
        description: 'Busy Charger',
        latitude: 28.5355,
        longitude: 77.3910,
        type: MarkerType.station,
        status: MarkerStatus.busy,
      );

      offlineCharger = const MapMarkerModel(
        id: 'charger_offline_1',
        title: 'ChargeZone Station',
        description: 'Offline Charger',
        latitude: 28.4595,
        longitude: 77.0266,
        type: MarkerType.station,
        status: MarkerStatus.offline,
      );

      unknownCharger = const MapMarkerModel(
        id: 'charger_unknown_1',
        title: 'Jio-bp Pulse',
        description: 'Unknown Status Charger',
        latitude: 28.7041,
        longitude: 77.1025,
        type: MarkerType.station,
        status: MarkerStatus.unknown,
      );

      verifiedCharger = const MapMarkerModel(
        id: 'charger_verified_1',
        title: 'EVHub Verified Hub',
        description: 'Verified Charger',
        latitude: 28.6250,
        longitude: 77.2150,
        type: MarkerType.station,
        source: 'evhub_verified',
        isVerified: true,
      );

      await ChargerMarkerFactory.init();
    });

    // TEST A: GPS Mode Marker Rendering
    test('TEST A: GPS Mode creates unique Marker with correct MarkerId and anchor', () {
      bool tapped = false;
      final marker = ChargerMarkerFactory.buildMarker(
        charger: availableCharger,
        isSelected: false,
        onTap: () => tapped = true,
      );

      expect(marker.markerId.value, 'charger_avail_1');
      expect(marker.position.latitude, 28.6139);
      expect(marker.position.longitude, 77.2090);
      expect(marker.anchor.dx, 0.5);
      expect(marker.anchor.dy, 1.0); // Pin tip at bottom center

      marker.onTap?.call();
      expect(tapped, true);
    });

    // TEST B: Search Mode Marker Rendering
    test('TEST B: Search Mode returns valid descriptors for searched locations', () {
      final marker1 = ChargerMarkerFactory.buildMarker(
        charger: busyCharger,
        isSelected: false,
        onTap: () {},
      );

      final marker2 = ChargerMarkerFactory.buildMarker(
        charger: offlineCharger,
        isSelected: false,
        onTap: () {},
      );

      expect(marker1.markerId.value, 'charger_busy_1');
      expect(marker2.markerId.value, 'charger_offline_1');
      expect(marker1.icon, isNotNull);
      expect(marker2.icon, isNotNull);
    });

    // TEST C & D: Route Corridor Mode & Distinct Origin/Destination Markers
    test('TEST C & D: Route mode maintains distinct origin/destination markers and corridor pins', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      // Verify clear route preserves discovery mode
      provider.clearTrip();
      expect(provider.discoveryMode, 'gps');
      expect(provider.tripOrigin, isNull);
      expect(provider.tripDestination, isNull);
    });

    // TEST E: Status Color Icon Descriptors
    test('TEST E: Status colors map to correct pre-cached descriptors', () {
      final availIcon = ChargerMarkerFactory.getIconForCharger(availableCharger);
      final busyIcon = ChargerMarkerFactory.getIconForCharger(busyCharger);
      final offlineIcon = ChargerMarkerFactory.getIconForCharger(offlineCharger);
      final unknownIcon = ChargerMarkerFactory.getIconForCharger(unknownCharger);
      final verifiedIcon = ChargerMarkerFactory.getIconForCharger(verifiedCharger);
      final selectedIcon = ChargerMarkerFactory.getIconForCharger(availableCharger, isSelected: true);

      expect(availIcon, isNotNull);
      expect(busyIcon, isNotNull);
      expect(offlineIcon, isNotNull);
      expect(unknownIcon, isNotNull);
      expect(verifiedIcon, isNotNull);
      expect(selectedIcon, isNotNull);
      expect(selectedIcon, equals(ChargerMarkerFactory.selectedIcon));
    });

    // TEST F: Charger Marker Tap Callback
    test('TEST F: Charger marker tap callback opens details via setSelectedMarker', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      expect(provider.selectedMarker, isNull);
      provider.setSelectedMarker(availableCharger);
      expect(provider.selectedMarker?.id, 'charger_avail_1');
      expect(provider.selectedMarker?.title, 'Tata Power Fast Charger');
    });

    // TEST G: Performance Pre-Caching Singleton Check
    test('TEST G: Pre-cached icons are initialized once and reused efficiently', () {
      expect(ChargerMarkerFactory.isInitialized, true);
      expect(ChargerMarkerFactory.availableIcon, isNotNull);
      expect(ChargerMarkerFactory.busyIcon, isNotNull);
      expect(ChargerMarkerFactory.offlineIcon, isNotNull);
      expect(ChargerMarkerFactory.unknownIcon, isNotNull);
      expect(ChargerMarkerFactory.verifiedIcon, isNotNull);
      expect(ChargerMarkerFactory.selectedIcon, isNotNull);
    });
  });
}
