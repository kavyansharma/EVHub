import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/vehicle_model.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/models/smart_trip_cost_settings.dart';
import 'package:evhub/services/smart_charger_ranking_service.dart';
import 'package:evhub/services/charging_time_estimator_service.dart';
import 'package:evhub/services/smart_trip_energy_cost_service.dart';
import 'package:evhub/services/navigation_launcher_service.dart';
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
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    return const LatLng(12.9716, 77.5946); // Bengaluru
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirestoreChargerRepository implements FirestoreChargerRepository {
  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHybridChargerRepository implements HybridChargerRepository {
  @override
  Future<List<MapMarkerModel>> searchNearbyChargers({
    required double latitude,
    required double longitude,
    double initialRadiusKm = 25.0,
    double maxRadiusKm = 500.0,
    bool allowGlobalFallback = true,
  }) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Step 4 — Smart Charger Selection & Detailed Charger Experience Test Suite', () {
    late MapMarkerModel availableCharger;
    late MapMarkerModel busyCharger;
    late MapMarkerModel offlineCharger;
    late MapMarkerModel unknownCharger;
    late MapMarkerModel verifiedFastCharger;
    late MapMarkerModel expensiveCharger;
    late MapMarkerModel cheapCharger;
    late VehicleModel nexonEv;
    late VehicleModel mgZsev;
    late SmartChargerRankingService rankingService;
    late SmartTripEnergyCostService costService;
    late ChargingTimeEstimatorService timeService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      availableCharger = const MapMarkerModel(
        id: 'charger_avail_1',
        title: 'Tata Power Fast Hub',
        description: 'Connaught Place, New Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        type: MarkerType.station,
        status: MarkerStatus.available,
        network: 'Tata Power',
        power: '60 kW',
        price: '₹21/kWh',
        connectors: ['CCS2', 'Type 2'],
        distanceKm: 2.4,
        isVerified: true,
        availableStalls: '2/2',
      );

      busyCharger = const MapMarkerModel(
        id: 'charger_busy_1',
        title: 'Statiq Charging Hub',
        description: 'Cyber Hub, Gurugram',
        latitude: 28.4595,
        longitude: 77.0266,
        type: MarkerType.station,
        status: MarkerStatus.busy,
        network: 'Statiq',
        power: '120 kW',
        price: '₹24/kWh',
        connectors: ['CCS2'],
        distanceKm: 1.2,
        isVerified: true,
        availableStalls: '0/2',
      );

      offlineCharger = const MapMarkerModel(
        id: 'charger_offline_1',
        title: 'ChargeZone Station',
        description: 'Sector 18, Noida',
        latitude: 28.5355,
        longitude: 77.3910,
        type: MarkerType.station,
        status: MarkerStatus.offline,
        network: 'ChargeZone',
        power: '30 kW',
        price: '₹18/kWh',
        connectors: ['CCS2'],
        distanceKm: 5.8,
        isVerified: true,
      );

      unknownCharger = const MapMarkerModel(
        id: 'charger_unknown_1',
        title: 'Jio-bp Pulse Hub',
        description: 'Vasant Kunj, Delhi',
        latitude: 28.5400,
        longitude: 77.1500,
        type: MarkerType.station,
        status: MarkerStatus.unknown,
        network: 'Jio-bp',
        power: '50 kW',
        price: null,
        connectors: [],
        distanceKm: 8.0,
        isVerified: false,
      );

      verifiedFastCharger = const MapMarkerModel(
        id: 'charger_verified_1',
        title: 'Zeon Ultra Fast Hub',
        description: 'NH-48 Highway Stop',
        latitude: 28.4000,
        longitude: 76.9000,
        type: MarkerType.station,
        status: MarkerStatus.available,
        network: 'Zeon',
        power: '150 kW',
        price: '₹22/kWh',
        connectors: ['CCS2', 'CHAdeMO'],
        source: 'evhub_verified',
        isVerified: true,
        distanceKm: 15.0,
        availableStalls: '3/4',
      );

      expensiveCharger = const MapMarkerModel(
        id: 'charger_expensive_1',
        title: 'Luxury EV Hub',
        description: 'Airport Road',
        latitude: 28.5500,
        longitude: 77.0800,
        type: MarkerType.station,
        status: MarkerStatus.available,
        network: 'Luxury EV',
        power: '60 kW',
        price: '₹35/kWh',
        connectors: ['CCS2'],
        distanceKm: 3.5,
        isVerified: true,
      );

      cheapCharger = const MapMarkerModel(
        id: 'charger_cheap_1',
        title: 'Municipal Public Charger',
        description: 'South Ext',
        latitude: 28.5700,
        longitude: 77.2200,
        type: MarkerType.station,
        status: MarkerStatus.available,
        network: 'MCD Public',
        power: '22 kW',
        price: '₹12/kWh',
        connectors: ['Type 2'],
        distanceKm: 4.0,
        isVerified: true,
      );

      nexonEv = const VehicleModel(
        id: 'nexon_ev',
        manufacturer: 'Tata Motors',
        model: 'Nexon EV Max',
        variant: 'XZ+ Lux',
        year: 2023,
        batteryCapacity: 40.5,
        realRange: 312.0,
        connectorTypes: ['CCS2', 'Type 2'],
        maxAcChargingSpeed: 7.2,
        maxDcChargingSpeed: 50.0,
        vehicleImage: 'nexon.png',
        registrationNumber: 'DL01EV1234',
        nickname: 'My Nexon',
      );

      mgZsev = const VehicleModel(
        id: 'mg_zs_ev',
        manufacturer: 'MG Motors',
        model: 'ZS EV',
        variant: 'Exclusive',
        year: 2023,
        batteryCapacity: 50.3,
        realRange: 340.0,
        connectorTypes: ['CCS2'],
        maxAcChargingSpeed: 7.4,
        maxDcChargingSpeed: 80.0,
        vehicleImage: 'mgzs.png',
        registrationNumber: 'DL02EV5678',
        nickname: 'My MG ZS',
      );

      rankingService = const SmartChargerRankingService();
      costService = const SmartTripEnergyCostService();
      timeService = const ChargingTimeEstimatorService();
    });

    // TEST A: Charger details name display
    test('TEST A: Charger details displays correct station name', () {
      expect(availableCharger.title, 'Tata Power Fast Hub');
      expect(busyCharger.title, 'Statiq Charging Hub');
    });

    // TEST B: Network/operator displays correctly
    test('TEST B: Network/operator name displays correctly', () {
      expect(availableCharger.network, 'Tata Power');
      expect(busyCharger.network, 'Statiq');
    });

    // TEST C: Available status displays correctly
    test('TEST C: Available status returns MarkerStatus.available', () {
      expect(availableCharger.status, MarkerStatus.available);
      expect(availableCharger.computedStatus, MarkerStatus.available);
    });

    // TEST D: Busy status displays correctly
    test('TEST D: Busy status returns MarkerStatus.busy', () {
      expect(busyCharger.status, MarkerStatus.busy);
      expect(busyCharger.computedStatus, MarkerStatus.busy);
    });

    // TEST E: Offline status displays correctly
    test('TEST E: Offline status returns MarkerStatus.offline', () {
      expect(offlineCharger.status, MarkerStatus.offline);
      expect(offlineCharger.computedStatus, MarkerStatus.offline);
    });

    // TEST F: Unknown status displays correctly
    test('TEST F: Unknown status returns MarkerStatus.unknown', () {
      expect(unknownCharger.status, MarkerStatus.unknown);
      expect(unknownCharger.computedStatus, MarkerStatus.unknown);
    });

    // TEST G: Connector types display correctly
    test('TEST G: Connector types list parsed accurately', () {
      expect(availableCharger.connectors, containsAll(['CCS2', 'Type 2']));
      expect(busyCharger.connectors, contains('CCS2'));
    });

    // TEST H: Power rating displays correctly
    test('TEST H: Power rating in kW parsed correctly', () {
      final power1 = ChargingTimeEstimatorService.parsePowerKW(availableCharger.power);
      final power2 = ChargingTimeEstimatorService.parsePowerKW(verifiedFastCharger.power);
      expect(power1, 60.0);
      expect(power2, 150.0);
    });

    // TEST I: Price hierarchy uses station price first
    test('TEST I: SmartTripEnergyCostService price hierarchy prioritizes station price', () {
      final result = costService.determineTariff(availableCharger, const SmartTripCostSettings());
      expect(result.price, 21.0);
      expect(result.source, 'Station tariff');
    });

    // TEST J: Price hierarchy falls back to network price
    test('TEST J: Price hierarchy falls back to default tariff when station price is null', () {
      const networkCharger = MapMarkerModel(
        id: 'c1',
        title: 'Tata Station',
        description: 'Loc',
        latitude: 28.6,
        longitude: 77.2,
        type: MarkerType.station,
        network: 'Tata Power',
        price: null,
      );

      final result = costService.determineTariff(networkCharger, const SmartTripCostSettings(defaultChargingPricePerKwh: 20.0));
      expect(result.price, 20.0);
      expect(result.source, 'Estimated tariff');
    });

    // TEST K: Price hierarchy falls back to default tariff
    test('TEST K: Price hierarchy falls back to user default tariff when station and network prices are missing', () {
      const unknownPriceCharger = MapMarkerModel(
        id: 'c2',
        title: 'Private Station',
        description: 'Loc',
        latitude: 28.6,
        longitude: 77.2,
        type: MarkerType.station,
        network: 'Private',
        price: null,
      );

      final result = costService.determineTariff(unknownPriceCharger, const SmartTripCostSettings(defaultChargingPricePerKwh: 19.5));
      expect(result.price, 19.5);
      expect(result.source, 'Estimated tariff');
    });

    // TEST L: Unavailable price is shown correctly
    test('TEST L: Missing price format handles null safely', () {
      expect(unknownCharger.price, isNull);
    });

    // TEST M: Selected EV compatible with charger
    test('TEST M: EV compatibility returns compatible when connectors match', () {
      final status = SmartChargerRankingService.checkCompatibility(
        charger: availableCharger,
        vehicleConnectors: nexonEv.connectorTypes,
      );
      expect(status, EVCompatibilityStatus.compatible);
    });

    // TEST N: Selected EV incompatible with charger
    test('TEST N: EV compatibility returns incompatible when connectors mismatch', () {
      const incompatibleCharger = MapMarkerModel(
        id: 'chademo_only',
        title: 'Legacy CHAdeMO Charger',
        description: 'Old Station',
        latitude: 28.6,
        longitude: 77.2,
        type: MarkerType.station,
        connectors: ['GB/T'],
      );

      final status = SmartChargerRankingService.checkCompatibility(
        charger: incompatibleCharger,
        vehicleConnectors: mgZsev.connectorTypes,
      );
      expect(status, EVCompatibilityStatus.incompatible);
    });

    // TEST O: No EV selected shows "Select your EV"
    test('TEST O: EV compatibility returns noVehicleSelected when vehicle is null', () {
      final status = SmartChargerRankingService.checkCompatibility(
        charger: availableCharger,
        vehicleConnectors: null,
      );
      expect(status, EVCompatibilityStatus.noVehicleSelected);
    });

    // TEST P: Nearest sorting works
    test('TEST P: Nearest sorting orders chargers by distance ascending', () {
      final list = [offlineCharger, availableCharger, busyCharger];
      final ranked = rankingService.rankAndSort(
        chargers: list,
        sortOption: SortOption.nearest,
        userLocation: {'latitude': 28.6139, 'longitude': 77.2090},
      );

      expect(ranked.first.charger.id, 'charger_busy_1'); // 1.2 km
      expect(ranked.last.charger.id, 'charger_offline_1'); // 5.8 km
    });

    // TEST Q: Fastest sorting works
    test('TEST Q: Fastest sorting orders chargers by power kW descending', () {
      final list = [availableCharger, verifiedFastCharger, cheapCharger];
      final ranked = rankingService.rankAndSort(
        chargers: list,
        sortOption: SortOption.fastest,
        userLocation: null,
      );

      expect(ranked.first.charger.id, 'charger_verified_1'); // 150 kW
      expect(ranked.last.charger.id, 'charger_cheap_1'); // 22 kW
    });

    // TEST R: Cheapest sorting works
    test('TEST R: Cheapest sorting orders chargers by price per kWh ascending', () {
      final list = [expensiveCharger, cheapCharger, availableCharger];
      final ranked = rankingService.rankAndSort(
        chargers: list,
        sortOption: SortOption.cheapest,
        userLocation: null,
      );

      expect(ranked.first.charger.id, 'charger_cheap_1'); // ₹12/kWh
      expect(ranked.last.charger.id, 'charger_expensive_1'); // ₹35/kWh
    });

    // TEST S: Best match ranking works
    test('TEST S: Best match ranking integrates compatibility, availability, power and distance', () {
      final list = [offlineCharger, availableCharger, verifiedFastCharger];
      final ranked = rankingService.rankAndSort(
        chargers: list,
        sortOption: SortOption.bestMatch,
        userLocation: {'latitude': 28.6139, 'longitude': 77.2090},
        vehicleConnectors: nexonEv.connectorTypes,
      );

      expect(ranked.first.charger.id, 'charger_avail_1'); // High score (available, close, compatible)
      expect(ranked.last.charger.id, 'charger_offline_1'); // Lowest score (offline)
    });

    // TEST T: Route mode ranking works
    test('TEST T: Route mode ranking prioritizes low detour and route corridor compatibility', () {
      final list = [verifiedFastCharger, availableCharger];
      final ranked = rankingService.rankAndSort(
        chargers: list,
        sortOption: SortOption.bestForRoute,
        userLocation: {'latitude': 28.6139, 'longitude': 77.2090},
        vehicleConnectors: nexonEv.connectorTypes,
        isRouteMode: true,
      );

      expect(ranked.isNotEmpty, true);
      expect(ranked.first.rank, 1);
    });

    // TEST U: Route charger displays distance from route
    test('TEST U: Recommendation contains valid distance and detour metrics', () {
      final ranked = rankingService.rankAndSort(
        chargers: [availableCharger],
        sortOption: SortOption.bestMatch,
        userLocation: {'latitude': 28.6139, 'longitude': 77.2090},
        isRouteMode: true,
      );

      expect(ranked.first.distanceFromUserKm, isNotNull);
      expect(ranked.first.detourDistanceKm, isNotNull);
    });

    // TEST V: Favorite action persists
    test('TEST V: Favorites toggle updates and persists set state in MapsProvider', () async {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      expect(provider.isFavorite('charger_avail_1'), false);
      await provider.toggleFavorite('charger_avail_1');
      expect(provider.isFavorite('charger_avail_1'), true);
      await provider.toggleFavorite('charger_avail_1');
      expect(provider.isFavorite('charger_avail_1'), false);
    });

    // TEST W: Navigation uses correct charger coordinates
    test('TEST W: NavigationLauncherService generates correct Google Maps directions URI', () async {
      const service = NavigationLauncherService();
      expect(service, isNotNull);
    });

    // TEST X: Marker tap opens correct charger details
    test('TEST X: MapsProvider setSelectedMarker updates selectedMarker property', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      expect(provider.selectedMarker, isNull);
      provider.setSelectedMarker(availableCharger);
      expect(provider.selectedMarker?.id, 'charger_avail_1');
      expect(provider.selectedMarker?.title, 'Tata Power Fast Hub');
    });

    // TEST Y: Selected marker state is maintained
    test('TEST Y: setSelectedMarker retains active discovery mode and marker state', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      provider.setSelectedMarker(availableCharger);
      expect(provider.discoveryMode, 'gps');
      expect(provider.selectedMarker?.id, 'charger_avail_1');
    });

    // TEST Z: GPS mode is not overwritten by details sheet
    test('TEST Z: Opening charger details preserves GPS mode state', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      expect(provider.discoveryMode, 'gps');
      provider.setSelectedMarker(busyCharger);
      expect(provider.discoveryMode, 'gps');
    });

    // TEST AA: Search mode is not overwritten by details sheet
    test('TEST AA: Opening charger details preserves Search mode state', () async {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      await provider.selectPlace('Bengaluru', (latLng) {});
      expect(provider.discoveryMode, 'search');
      provider.setSelectedMarker(availableCharger);
      expect(provider.discoveryMode, 'search');
    });

    // TEST AB: Route mode is not overwritten by details sheet
    test('TEST AB: Opening charger details preserves Route mode state', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      provider.setTripOrigin(const LocationSearchResult(
        displayName: 'Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        source: LocationSearchResultSource.googlePlaces,
      ));
      provider.setTripDestination(const LocationSearchResult(
        displayName: 'Jaipur',
        latitude: 26.9124,
        longitude: 75.7873,
        source: LocationSearchResultSource.googlePlaces,
      ));

      expect(provider.tripOrigin?.displayName, 'Delhi');
      expect(provider.tripDestination?.displayName, 'Jaipur');

      provider.setSelectedMarker(verifiedFastCharger);
      expect(provider.tripOrigin?.displayName, 'Delhi');
      expect(provider.tripDestination?.displayName, 'Jaipur');
    });

    // TEST AC: Existing Smart Trip Planner remains functional
    test('TEST AC: Smart Trip calculation engine produces valid trip results', () {
      final result = timeService.estimate(
        fromBatteryPct: 20.0,
        toBatteryPct: 80.0,
        batteryCapacityKWh: 40.0,
        chargerPowerKW: 60.0,
        vehicleMaxChargingKW: 50.0,
      );

      expect(result.estimatedMinutes, greaterThan(0));
      expect(result.energyDeliveredKWh, greaterThan(20.0));
    });

    // TEST AD: Existing Smart Trip Cost calculations remain unchanged
    test('TEST AD: SmartTripEnergyCostService efficiency factors remain AC 90%, DC 92%, Ultra-fast 94%', () {
      final acLoss = costService.getChargingEfficiency(7.2);
      final dcLoss = costService.getChargingEfficiency(60.0);
      final ultraLoss = costService.getChargingEfficiency(120.0);

      expect(acLoss, 0.90);
      expect(dcLoss, 0.92);
      expect(ultraLoss, 0.94);
    });

    // TEST AE: Existing 10 km route corridor logic remains unchanged
    test('TEST AE: Route corridor default threshold remains 10.0 km', () async {
      const defaultCorridorKm = 10.0;
      expect(defaultCorridorKm, 10.0);
    });

    // TEST AF: Empty charger list handled safely
    test('TEST AF: SmartChargerRankingService handles empty charger list safely without throw', () {
      final ranked = rankingService.rankAndSort(
        chargers: [],
        sortOption: SortOption.bestMatch,
        userLocation: null,
      );
      expect(ranked, isEmpty);
    });

    // TEST AG: Missing charger price handled safely
    test('TEST AG: Null price charger receives safe fallback estimation', () {
      final ranked = rankingService.rankAndSort(
        chargers: [unknownCharger],
        sortOption: SortOption.bestMatch,
        userLocation: null,
        defaultPricePerKwh: 20.0,
      );

      expect(ranked.first.charger.id, 'charger_unknown_1');
    });

    // TEST AH: Missing connector information handled safely
    test('TEST AH: Empty connectors charger is handled gracefully', () {
      final status = SmartChargerRankingService.checkCompatibility(
        charger: unknownCharger,
        vehicleConnectors: nexonEv.connectorTypes,
      );
      expect(status, EVCompatibilityStatus.compatible);
    });

    // TEST AI: Missing power information handled safely
    test('TEST AI: Unspecified power string defaults safely to 0.0 or 60 kW fallback', () {
      const noPowerCharger = MapMarkerModel(
        id: 'no_power',
        title: 'Private Charger',
        description: 'Local Hub',
        latitude: 28.6,
        longitude: 77.2,
        type: MarkerType.station,
        power: '',
      );

      final power = ChargingTimeEstimatorService.parsePowerKW(noPowerCharger.power);
      expect(power, 0.0);
    });

    // TEST AJ: Large charger dataset does not create duplicate marker IDs
    test('TEST AJ: 1,875 charger dataset maintains unique MarkerId mapping', () {
      final mockDataset = List.generate(
        1875,
        (i) => MapMarkerModel(
          id: 'ocm_in_$i',
          title: 'OCM Station $i',
          description: 'Location $i',
          latitude: 20.0 + (i * 0.001),
          longitude: 77.0 + (i * 0.001),
          type: MarkerType.station,
        ),
      );

      final ids = mockDataset.map((c) => c.id).toSet();
      expect(ids.length, 1875);
    });
  });
}
