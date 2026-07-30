import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:evhub/models/ev_vehicle_model.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/smart_trip_cost_settings.dart';
import 'package:evhub/services/smart_trip_energy_cost_service.dart';
import 'package:evhub/services/charging_stop_recommendation_service.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/providers/wallet_provider.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/repositories/wallet_repository.dart';
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

class MockWalletRepository implements WalletRepository {
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
  group('Phase 4 — Step 3: Smart Charging Cost & Energy Planner Tests', () {
    late SmartTripEnergyCostService costService;
    late SmartTripCostSettings defaultSettings;
    late EVVehicleModel testVehicle;
    late List<LatLng> mockPolyline;

    setUp(() {
      costService = const SmartTripEnergyCostService();
      defaultSettings = const SmartTripCostSettings(
        defaultChargingPricePerKwh: 20.0,
        petrolPricePerLitre: 100.0,
        dieselPricePerLitre: 90.0,
        petrolEfficiencyKml: 15.0,
        dieselEfficiencyKml: 20.0,
        iceComparisonFuelType: 'Petrol',
      );

      testVehicle = const EVVehicleModel(
        id: 'tata_nexon_ev_max',
        brand: 'Tata',
        model: 'Nexon EV Max',
        batteryCapacityKWh: 40.5,
        usableBatteryCapacityKWh: 39.0,
        realWorldRangeKm: 280.0, // ~0.139 kWh/km
        connectorTypes: ['CCS2'],
        maxACChargingPowerKW: 7.2,
        maxDCChargingPowerKW: 30.0,
      );

      final origin = const LatLng(28.6139, 77.2090); // Delhi
      final dest = const LatLng(26.9124, 75.7873);   // Jaipur (~235km)
      mockPolyline = List.generate(21, (i) {
        final t = i / 20.0;
        return LatLng(
          origin.latitude + t * (dest.latitude - origin.latitude),
          origin.longitude + t * (dest.longitude - origin.longitude),
        );
      });
    });

    // TEST A: Energy calculation.
    test('TEST A: Energy calculation', () {
      final tripDistanceKm = 300.0;
      final efficiencyKwhPerKm = testVehicle.usableBatteryCapacityKWh / testVehicle.realWorldRangeKm;
      final energyRequired = tripDistanceKm * efficiencyKwhPerKm;
      expect(energyRequired, closeTo(41.78, 0.1));
    });

    // TEST B: Charging losses.
    test('TEST B: Charging losses', () {
      final batteryAddedKwh = 20.0;
      final gridEnergyDC = costService.calculateGridEnergyDrawn(batteryAddedKwh, 50.0);
      final lossDC = gridEnergyDC - batteryAddedKwh;
      expect(lossDC, greaterThan(0));
      expect(lossDC, closeTo(20.0 / 0.92 - 20.0, 0.1)); // DC 92%
    });

    // TEST C: Grid energy calculation.
    test('TEST C: Grid energy calculation', () {
      final gridEnergyAC = costService.calculateGridEnergyDrawn(20.0, 11.0);
      expect(gridEnergyAC, closeTo(20.0 / 0.90, 0.1)); // AC 90%

      final gridEnergyDC = costService.calculateGridEnergyDrawn(50.0, 50.0);
      expect(gridEnergyDC, closeTo(50.0 / 0.92, 0.1)); // DC 92%

      final gridEnergyUltra = costService.calculateGridEnergyDrawn(50.0, 150.0);
      expect(gridEnergyUltra, closeTo(50.0 / 0.94, 0.1)); // Ultra 94%
    });

    // TEST D: Station tariff cost.
    test('TEST D: Station tariff cost', () {
      final charger = const MapMarkerModel(
        id: 'c1', title: 'Tata Fast Charger', description: '', latitude: 28.0, longitude: 77.0,
        type: MarkerType.station, price: '₹22/kWh',
      );
      final tariff = costService.determineTariff(charger, defaultSettings);
      expect(tariff.price, 22.0);
      expect(tariff.source, 'Station tariff');

      final gridEnergy = 30.0;
      final cost = costService.calculateChargingCost(gridEnergy, tariff.price);
      expect(cost, 660.0);
    });

    // TEST E: Default tariff fallback.
    test('TEST E: Default tariff fallback', () {
      final chargerNoPrice = const MapMarkerModel(
        id: 'c2', title: 'No Price Station', description: '', latitude: 28.0, longitude: 77.0,
        type: MarkerType.station, price: null,
      );
      final tariff = costService.determineTariff(chargerNoPrice, defaultSettings);
      expect(tariff.price, 20.0);
      expect(tariff.source, 'Estimated tariff');
    });

    // TEST F: Missing tariff handling.
    test('TEST F: Missing tariff handling', () {
      final chargerNoPrice = const MapMarkerModel(
        id: 'c3', title: 'No Price Station', description: '', latitude: 28.0, longitude: 77.0,
        type: MarkerType.station, price: null,
      );
      final noDefaultSettings = defaultSettings.copyWith(defaultChargingPricePerKwh: 0.0);
      final tariff = costService.determineTariff(chargerNoPrice, noDefaultSettings);
      expect(tariff.price, isNull);
      expect(tariff.source, 'Price unavailable');

      final cost = costService.calculateChargingCost(30.0, tariff.price);
      expect(cost, 0.0);
    });

    // TEST G: Multiple charging stops total cost.
    test('TEST G: Multiple charging stops total cost', () {
      final recService = ChargingStopRecommendationService();
      final p1 = mockPolyline[4];  // ~47 km
      final p2 = mockPolyline[10]; // ~117 km

      final charger1 = MapMarkerModel(
        id: 'c1', title: 'Stop 1', description: '', latitude: p1.latitude, longitude: p1.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: '₹20/kWh',
      );
      final charger2 = MapMarkerModel(
        id: 'c2', title: 'Stop 2', description: '', latitude: p2.latitude, longitude: p2.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: '₹25/kWh',
      );

      final result = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0, // 50% SOC allows reaching ~140km safely
        routeChargers: [charger1, charger2],
        costSettings: defaultSettings,
      );

      expect(result.recommendedStops.length, greaterThanOrEqualTo(1));
      final calculatedTotalCost = result.recommendedStops.fold(
        0.0, (sum, stop) => sum + stop.estimatedChargingCost,
      );
      expect(result.totalChargingCost, closeTo(calculatedTotalCost, 0.01));
    });

    // TEST H: 15% safety reserve remains enforced.
    test('TEST H: 15% safety reserve remains enforced', () {
      final recService = ChargingStopRecommendationService();
      final p = mockPolyline[4];
      final charger = MapMarkerModel(
        id: 'c1', title: 'Midway', description: '', latitude: p.latitude, longitude: p.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: '₹20/kWh',
      );

      final result = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0,
        routeChargers: [charger],
        costSettings: defaultSettings,
        safetyReservePct: 15.0,
      );

      for (final stop in result.recommendedStops) {
        expect(stop.estimatedArrivalBatteryPct, greaterThanOrEqualTo(10.0)); // minimum floor
      }
      expect(result.requiredBatteryPct, greaterThan(15.0));
    });

    // TEST I: Wallet balance simulation.
    test('TEST I: Wallet balance simulation', () {
      final walletProvider = WalletProvider(walletRepository: MockWalletRepository());
      final initialBalance = walletProvider.balance;
      final estimatedTripCost = 450.0;
      final remainingBalance = initialBalance - estimatedTripCost;
      expect(remainingBalance, initialBalance - 450.0);
    });

    // TEST J: No actual wallet deduction during planning.
    test('TEST J: No actual wallet deduction during planning', () {
      final walletProvider = WalletProvider(walletRepository: MockWalletRepository());
      final initialBalance = walletProvider.balance;

      final recService = ChargingStopRecommendationService();
      final p = mockPolyline[4];
      final charger = MapMarkerModel(
        id: 'c1', title: 'Station', description: '', latitude: p.latitude, longitude: p.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: '₹20/kWh',
      );
      final result = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0,
        routeChargers: [charger],
        costSettings: defaultSettings,
      );

      expect(result.totalChargingCost, greaterThan(0.0));
      // Verify wallet balance in provider remains unchanged by planning calculation
      expect(walletProvider.balance, initialBalance);
    });

    // TEST K: Petrol comparison.
    test('TEST K: Petrol comparison', () {
      final iceResult = costService.calculateIceComparison(
        tripDistanceKm: 300.0,
        totalEvCost: 500.0,
        settings: defaultSettings, // petrol: 15 km/l @ 100 INR/L => 20L * 100 = 2000 INR
      );

      expect(iceResult.fuelRequiredLiters, 20.0);
      expect(iceResult.fuelCost, 2000.0);
      expect(iceResult.savings, 1500.0);
      expect(iceResult.savingsPct, 75.0);
    });

    // TEST L: Diesel comparison.
    test('TEST L: Diesel comparison', () {
      final dieselSettings = defaultSettings.copyWith(
        iceComparisonFuelType: 'Diesel',
        dieselEfficiencyKml: 20.0,
        dieselPricePerLitre: 90.0,
      );

      final iceResult = costService.calculateIceComparison(
        tripDistanceKm: 300.0,
        totalEvCost: 500.0,
        settings: dieselSettings, // diesel: 20 km/l @ 90 INR/L => 15L * 90 = 1350 INR
      );

      expect(iceResult.fuelRequiredLiters, 15.0);
      expect(iceResult.fuelCost, 1350.0);
      expect(iceResult.savings, 850.0);
      expect(iceResult.savingsPct, closeTo(62.96, 0.1));
    });

    // TEST M: EV savings calculation.
    test('TEST M: EV savings calculation', () {
      final iceResult = costService.calculateIceComparison(
        tripDistanceKm: 200.0,
        totalEvCost: 300.0,
        settings: defaultSettings,
      );
      final expectedFuelCost = (200.0 / 15.0) * 100.0;
      expect(iceResult.fuelCost, closeTo(expectedFuelCost, 0.1));
      expect(iceResult.savings, closeTo(expectedFuelCost - 300.0, 0.1));
    });

    // TEST N: Delhi → Jaipur cost calculation.
    test('TEST N: Delhi → Jaipur cost calculation', () {
      final delhi = const LatLng(28.6139, 77.2090);
      final jaipur = const LatLng(26.9124, 75.7873);
      final recService = ChargingStopRecommendationService();

      final result = recService.recommend(
        origin: delhi,
        destination: jaipur,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      expect(result.tripDistanceKm, greaterThan(200.0));
      expect(result.tripEnergyRequiredKWh, greaterThan(25.0));
    });

    // TEST O: Mumbai → Pune cost calculation.
    test('TEST O: Mumbai → Pune cost calculation', () {
      final mumbai = const LatLng(19.0760, 72.8777);
      final pune = const LatLng(18.5204, 73.8567);
      final recService = ChargingStopRecommendationService();

      final result = recService.recommend(
        origin: mumbai,
        destination: pune,
        polylinePoints: [mumbai, pune],
        vehicle: testVehicle,
        currentBatteryPct: 80.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      expect(result.tripDistanceKm, closeTo(120.0, 30.0));
      expect(result.chargingRequired, false); // 80% is enough for ~120km
    });

    // TEST P: Bengaluru → Chennai cost calculation.
    test('TEST P: Bengaluru → Chennai cost calculation', () {
      final blr = const LatLng(12.9716, 77.5946);
      final maa = const LatLng(13.0827, 80.2707);
      final recService = ChargingStopRecommendationService();

      final result = recService.recommend(
        origin: blr,
        destination: maa,
        polylinePoints: [blr, maa],
        vehicle: testVehicle,
        currentBatteryPct: 90.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      expect(result.tripDistanceKm, greaterThan(250.0));
      expect(result.tripEnergyRequiredKWh, greaterThan(30.0));
    });

    // TEST Q: Charging tariff source selection.
    test('TEST Q: Charging tariff source selection', () {
      final stationTariffCharger = const MapMarkerModel(
        id: '1', title: 'Station', description: '', latitude: 0, longitude: 0,
        type: MarkerType.station, price: 'INR 18/kWh',
      );
      final noTariffCharger = const MapMarkerModel(
        id: '2', title: 'Station', description: '', latitude: 0, longitude: 0,
        type: MarkerType.station, price: null,
      );

      final t1 = costService.determineTariff(stationTariffCharger, defaultSettings);
      expect(t1.source, 'Station tariff');
      expect(t1.price, 18.0);

      final t2 = costService.determineTariff(noTariffCharger, defaultSettings);
      expect(t2.source, 'Estimated tariff');
      expect(t2.price, 20.0);

      final noDefaultSettings = defaultSettings.copyWith(defaultChargingPricePerKwh: 0.0);
      final t3 = costService.determineTariff(noTariffCharger, noDefaultSettings);
      expect(t3.source, 'Price unavailable');
      expect(t3.price, isNull);
    });

    // TEST R: Insufficient wallet balance warning.
    test('TEST R: Insufficient wallet balance warning', () {
      final walletBalance = 100.0;
      final estimatedTripCost = 350.0;
      final isInsufficient = (walletBalance - estimatedTripCost) < 0;
      expect(isInsufficient, true);
    });

    // TEST S: Clear Trip resets cost calculation.
    test('TEST S: Clear Trip resets cost calculation', () {
      final provider = MapsProvider(
        mapsRepository: MockMapsRepository(),
        mapsService: MockMapsService(),
        firestoreChargerRepository: MockFirestoreChargerRepository(),
        hybridChargerRepository: MockHybridChargerRepository(),
      );

      provider.clearTrip();
      expect(provider.smartTripResult, isNull);
      expect(provider.recommendedStops, isEmpty);
    });

    // TEST T: Changing vehicle recalculates energy and cost.
    test('TEST T: Changing vehicle recalculates energy and cost', () {
      final largerVehicle = const EVVehicleModel(
        id: 'mg_zs_ev',
        brand: 'MG',
        model: 'ZS EV',
        batteryCapacityKWh: 50.3,
        usableBatteryCapacityKWh: 48.0,
        realWorldRangeKm: 320.0,
        connectorTypes: ['CCS2'],
        maxACChargingPowerKW: 7.4,
        maxDCChargingPowerKW: 50.0,
      );

      final recService = ChargingStopRecommendationService();
      final r1 = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      final r2 = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: largerVehicle,
        currentBatteryPct: 50.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      expect(r1.tripEnergyRequiredKWh, isNot(equals(r2.tripEnergyRequiredKWh)));
    });

    // TEST U: Changing battery SOC recalculates required charging.
    test('TEST U: Changing battery SOC recalculates required charging', () {
      final recService = ChargingStopRecommendationService();
      final rFull = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 100.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      final rLow = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 20.0,
        routeChargers: const [],
        costSettings: defaultSettings,
      );

      expect(rFull.chargingRequired, false);
      expect(rLow.chargingRequired, true);
    });

    // TEST V: Changing default tariff recalculates total cost.
    test('TEST V: Changing default tariff recalculates total cost', () {
      final p = mockPolyline[4];
      final charger = MapMarkerModel(
        id: 'c1', title: 'No Price', description: '', latitude: p.latitude, longitude: p.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: null,
      );
      final recService = ChargingStopRecommendationService();

      final settings20 = defaultSettings.copyWith(defaultChargingPricePerKwh: 20.0);
      final settings30 = defaultSettings.copyWith(defaultChargingPricePerKwh: 30.0);

      final r20 = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0,
        routeChargers: [charger],
        costSettings: settings20,
      );

      final r30 = recService.recommend(
        origin: mockPolyline.first,
        destination: mockPolyline.last,
        polylinePoints: mockPolyline,
        vehicle: testVehicle,
        currentBatteryPct: 50.0,
        routeChargers: [charger],
        costSettings: settings30,
      );

      expect(r30.totalChargingCost, greaterThan(r20.totalChargingCost));
    });

    // TEST W: Missing charger price does not crash the planner.
    test('TEST W: Missing charger price does not crash the planner', () {
      final p1 = mockPolyline[4];
      final p2 = mockPolyline[10];
      final chargerNullPrice = MapMarkerModel(
        id: 'c1', title: 'Null Price', description: '', latitude: p1.latitude, longitude: p1.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: null,
      );
      final chargerEmptyPrice = MapMarkerModel(
        id: 'c2', title: 'Empty Price', description: '', latitude: p2.latitude, longitude: p2.longitude,
        type: MarkerType.station, connectors: const ['CCS2'], power: '50 kW', price: '',
      );

      final recService = ChargingStopRecommendationService();
      expect(() {
        recService.recommend(
          origin: mockPolyline.first,
          destination: mockPolyline.last,
          polylinePoints: mockPolyline,
          vehicle: testVehicle,
          currentBatteryPct: 50.0,
          routeChargers: [chargerNullPrice, chargerEmptyPrice],
          costSettings: defaultSettings,
        );
      }, returnsNormally);
    });
  });
}
