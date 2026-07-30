import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evhub/models/location_search_result.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/vehicle_model.dart';
import 'package:evhub/providers/maps_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/hybrid_charger_repository.dart';
import 'package:evhub/repositories/maps_repository.dart';
import 'package:evhub/services/maps_service.dart';
import 'package:evhub/services/trip_energy_calculator.dart';
import 'package:evhub/services/vehicle_service.dart';

class MockMapsRepo implements MapsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMapsService implements MapsService {
  @override
  Future<Map<String, dynamic>?> getDirections(LatLng origin, LatLng dest) async {
    return {
      'distance': '280 km',
      'duration': '5 hr 30 min',
      'points': [
        origin,
        LatLng((origin.latitude + dest.latitude) / 2, (origin.longitude + dest.longitude) / 2),
        dest,
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirestoreRepo implements FirestoreChargerRepository {
  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 — Step 2A: Vehicle & Battery Intelligence Test Suite', () {
    const testNexonEV = VehicleModel(
      id: 'tata-nexon-ev-test',
      manufacturer: 'Tata',
      model: 'Nexon EV',
      variant: 'LR',
      year: 2024,
      batteryCapacity: 40.5,
      usableBatteryCapacityKWh: 40.5,
      realRange: 290.0,
      averageEfficiency: 160.0, // 0.16 kWh/km
      connectorTypes: ['CCS2'],
      maxAcChargingSpeed: 7.2,
      maxDcChargingSpeed: 50.0,
      vehicleImage: '',
      registrationNumber: '',
      nickname: 'Test Nexon',
    );

    const testCometEV = VehicleModel(
      id: 'mg-comet-ev-test',
      manufacturer: 'MG',
      model: 'Comet EV',
      variant: 'Pace',
      year: 2024,
      batteryCapacity: 17.3,
      usableBatteryCapacityKWh: 17.3,
      realRange: 180.0,
      averageEfficiency: 95.0, // 0.095 kWh/km
      connectorTypes: ['Type 2'],
      maxAcChargingSpeed: 3.3,
      maxDcChargingSpeed: 3.3,
      vehicleImage: '',
      registrationNumber: '',
      nickname: 'Test Comet',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('TEST 1: Vehicle selection and catalog loading', () async {
      final vehicles = await VehicleService().getAvailableVehicles();
      expect(vehicles.length, greaterThanOrEqualTo(10));

      final nexon = vehicles.firstWhere((v) => v.model == 'Nexon EV');
      expect(nexon.batteryCapacity, equals(40.5));
      expect(nexon.usableBatteryCapacity, equals(40.5));
      expect(nexon.displayName, contains('Nexon EV'));
    });

    test('TEST 2: Available energy calculation (40.5 kWh * 75% = 30.375 kWh)', () {
      final energy = TripEnergyCalculator.calculateAvailableEnergy(
        batteryCapacityKwh: 40.5,
        batteryPct: 75.0,
      );
      expect(energy, equals(30.375));
    });

    test('TEST 3: Remaining range calculation (30.375 kWh / 0.16 kWh/km = ~189.84 km)', () {
      final range = TripEnergyCalculator.calculateEstimatedRange(
        availableEnergyKwh: 30.375,
        efficiencyWhPerKm: 160.0,
      );
      expect(range, closeTo(189.84, 0.1));
    });

    test('TEST 4: Trip energy requirement calculation (280 km * 0.16 kWh/km = 44.8 kWh)', () {
      final energyRequired = TripEnergyCalculator.calculateTripEnergy(
        tripDistanceKm: 280.0,
        efficiencyWhPerKm: 160.0,
      );
      expect(energyRequired, closeTo(44.8, 0.01));
    });

    test('TEST 5: Charging required status when remaining range < trip distance with safety buffer', () {
      final analysis = TripEnergyCalculator.analyze(
        vehicle: testNexonEV,
        batteryPct: 75.0, // 30.375 kWh -> ~189.8 km range
        tripDistanceKm: 280.0, // 280 km distance -> 322 km with 15% buffer
        safetyBufferPct: 15.0,
      );

      expect(analysis.status, equals(ChargingRequirementStatus.chargingRequired));
      expect(analysis.statusTitle, equals('Charging Recommended'));
      expect(analysis.statusMessage, contains('need to charge'));
    });

    test('TEST 6: Charging not required status when remaining range >= trip distance with safety buffer', () {
      final analysis = TripEnergyCalculator.analyze(
        vehicle: testNexonEV,
        batteryPct: 100.0, // 40.5 kWh -> ~253.1 km range
        tripDistanceKm: 150.0, // 150 km distance -> 172.5 km with 15% buffer
        safetyBufferPct: 15.0,
      );

      expect(analysis.status, equals(ChargingRequirementStatus.rangeSufficient));
      expect(analysis.statusTitle, equals('Range Check'));
      expect(analysis.statusMessage, contains('range is sufficient'));
    });

    test('TEST 7: Safety buffer 15% calculation (280 km -> 322 km)', () {
      final reqRange = TripEnergyCalculator.calculateRequiredRangeWithBuffer(
        tripDistanceKm: 280.0,
        safetyBufferPct: 15.0,
      );
      expect(reqRange, equals(322.0));
    });

    test('TEST 8: Battery percentage validation (0% valid, 100% valid, negative/over-100 clamped)', () {
      final energy0 = TripEnergyCalculator.calculateAvailableEnergy(
        batteryCapacityKwh: 40.5,
        batteryPct: 0.0,
      );
      expect(energy0, equals(0.0));

      final energy100 = TripEnergyCalculator.calculateAvailableEnergy(
        batteryCapacityKwh: 40.5,
        batteryPct: 100.0,
      );
      expect(energy100, equals(40.5));

      final energyNegative = TripEnergyCalculator.calculateAvailableEnergy(
        batteryCapacityKwh: 40.5,
        batteryPct: -25.0,
      );
      expect(energyNegative, equals(0.0));

      final energyOver100 = TripEnergyCalculator.calculateAvailableEnergy(
        batteryCapacityKwh: 40.5,
        batteryPct: 150.0,
      );
      expect(energyOver100, equals(40.5));
    });

    test('TEST 9: Vehicle switching in MapsProvider updates calculations dynamically', () async {
      final fsRepo = MockFirestoreRepo();
      final mapsService = MockMapsService();
      final mapsRepo = MockMapsRepo();
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: fsRepo,
        mapsService: mapsService,
      );

      final provider = MapsProvider(
        mapsRepository: mapsRepo,
        mapsService: mapsService,
        firestoreChargerRepository: fsRepo,
        hybridChargerRepository: hybridRepo,
      );

      await provider.setSelectedVehicle(testNexonEV);
      await provider.setCurrentBatteryPct(75.0);

      expect(provider.tripEnergyAnalysis.availableEnergyKwh, closeTo(30.375, 0.001));

      // Switch to MG Comet EV (17.3 kWh)
      await provider.setSelectedVehicle(testCometEV);
      expect(provider.tripEnergyAnalysis.availableEnergyKwh, closeTo(12.975, 0.001));
    });

    test('TEST 10: Battery % switching from 75% to 50% updates available energy & range', () async {
      final fsRepo = MockFirestoreRepo();
      final mapsService = MockMapsService();
      final mapsRepo = MockMapsRepo();
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: fsRepo,
        mapsService: mapsService,
      );

      final provider = MapsProvider(
        mapsRepository: mapsRepo,
        mapsService: mapsService,
        firestoreChargerRepository: fsRepo,
        hybridChargerRepository: hybridRepo,
      );

      await provider.setSelectedVehicle(testNexonEV);
      await provider.setCurrentBatteryPct(75.0);
      expect(provider.tripEnergyAnalysis.availableEnergyKwh, closeTo(30.375, 0.001));

      await provider.setCurrentBatteryPct(50.0);
      expect(provider.tripEnergyAnalysis.availableEnergyKwh, closeTo(20.25, 0.001));
    });

    test('TEST 11: Trip distance update recalculates energy requirement', () async {
      final fsRepo = MockFirestoreRepo();
      final mapsService = MockMapsService();
      final mapsRepo = MockMapsRepo();
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: fsRepo,
        mapsService: mapsService,
      );

      final provider = MapsProvider(
        mapsRepository: mapsRepo,
        mapsService: mapsService,
        firestoreChargerRepository: fsRepo,
        hybridChargerRepository: hybridRepo,
      );

      final nexon = VehicleService.indianEVEcosystem.first; // 140 Wh/km
      await provider.setSelectedVehicle(nexon);
      await provider.planTrip(
        origin: const LocationSearchResult(
          displayName: 'Delhi', latitude: 28.6139, longitude: 77.2090,
          source: LocationSearchResultSource.localFallback,
        ),
        destination: const LocationSearchResult(
          displayName: 'Jaipur', latitude: 26.9124, longitude: 75.7873,
          source: LocationSearchResultSource.localFallback,
        ),
      );

      // Route distance is 280 km -> trip energy = 280 * 0.14 = 39.2 kWh
      expect(provider.tripEnergyAnalysis.tripEnergyRequiredKwh, closeTo(39.2, 0.1));
    });

    test('TEST 12: Clear Trip clears route state while preserving vehicle & battery settings', () async {
      final fsRepo = MockFirestoreRepo();
      final mapsService = MockMapsService();
      final mapsRepo = MockMapsRepo();
      final hybridRepo = HybridChargerRepository(
        firestoreRepository: fsRepo,
        mapsService: mapsService,
      );

      final provider = MapsProvider(
        mapsRepository: mapsRepo,
        mapsService: mapsService,
        firestoreChargerRepository: fsRepo,
        hybridChargerRepository: hybridRepo,
      );

      final nexon = VehicleService.indianEVEcosystem.first;
      await provider.setSelectedVehicle(nexon);
      await provider.setCurrentBatteryPct(75.0);
      await provider.planTrip(
        origin: const LocationSearchResult(
          displayName: 'Delhi', latitude: 28.6139, longitude: 77.2090,
          source: LocationSearchResultSource.localFallback,
        ),
        destination: const LocationSearchResult(
          displayName: 'Jaipur', latitude: 26.9124, longitude: 75.7873,
          source: LocationSearchResultSource.localFallback,
        ),
      );

      expect(provider.discoveryMode, equals('route'));
      provider.clearTrip();

      expect(provider.discoveryMode, equals('gps'));
      expect(provider.routePoints, isEmpty);
      // Vehicle and battery settings remain preserved
      expect(provider.selectedVehicle?.id, equals(nexon.id));
      expect(provider.currentBatteryPct, equals(75.0));
    });
  });
}
