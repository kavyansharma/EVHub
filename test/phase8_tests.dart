import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/charging_session_model.dart';
import 'package:evhub/core/utils/smart_charging_calculator.dart';

void main() {
  group('Phase 8 — Real-Time Charger Intelligence & Smart Charging Tests', () {
    test('MarkerStatus computedStatus returns correct status for verified and unverified chargers', () {
      // Available verified charger
      const availMarker = MapMarkerModel(
        id: 'c1',
        title: 'Tata Power CP',
        description: 'Connaught Place',
        latitude: 28.6304,
        longitude: 77.2177,
        type: MarkerType.station,
        source: 'evhub_verified',
        isVerified: true,
        availableStalls: '3/4',
        status: MarkerStatus.available,
      );
      expect(availMarker.availableConnectorsCount, equals(3));
      expect(availMarker.occupiedConnectorsCount, equals(1));
      expect(availMarker.computedStatus, equals(MarkerStatus.available));

      // Busy verified charger (0 available)
      const busyMarker = MapMarkerModel(
        id: 'c2',
        title: 'Statiq Hub',
        description: 'Cyber City',
        latitude: 28.4900,
        longitude: 77.0900,
        type: MarkerType.station,
        source: 'evhub_verified',
        isVerified: true,
        availableStalls: '0/4',
        status: MarkerStatus.available,
      );
      expect(busyMarker.availableConnectorsCount, equals(0));
      expect(busyMarker.occupiedConnectorsCount, equals(4));
      expect(busyMarker.computedStatus, equals(MarkerStatus.busy));

      // Explicitly offline charger
      const offlineMarker = MapMarkerModel(
        id: 'c3',
        title: 'Offline Station',
        description: 'Maintenance',
        latitude: 28.5000,
        longitude: 77.1000,
        type: MarkerType.station,
        source: 'evhub_verified',
        isVerified: true,
        availableStalls: '0/2',
        status: MarkerStatus.offline,
      );
      expect(offlineMarker.computedStatus, equals(MarkerStatus.offline));

      // Google Places charger with unknown availability
      const googleMarker = MapMarkerModel(
        id: 'g1',
        title: 'Google Places Station',
        description: 'Google Places Discovery',
        latitude: 28.6000,
        longitude: 77.2000,
        type: MarkerType.station,
        source: 'google_places',
        isVerified: false,
        availableStalls: 'Availability Unknown',
        status: MarkerStatus.unknown,
      );
      expect(googleMarker.availableConnectorsCount, equals(0));
      expect(googleMarker.computedStatus, equals(MarkerStatus.unknown));
    });

    test('SmartChargingCalculator computes accurate time, energy, cost, and efficiency', () {
      final result = SmartChargingCalculator.calculate(
        currentBatteryPct: 20.0,
        targetBatteryPct: 80.0,
        chargerPowerKw: 60.0,
        vehicleMaxPowerKw: 100.0,
        batteryCapacityKwh: 50.0,
        pricePerKwh: 20.0,
        powerType: 'Fast', // 92% efficiency
      );

      // 60% of 50kWh = 30kWh net
      expect(result.energyRequiredKwh, equals(30.0));
      expect(result.efficiencyPercentage, equals(92));
      // Gross grid energy = 30 / 0.92 = ~32.6 kWh
      expect(result.grossEnergyFromGridKwh, closeTo(32.6, 0.2));
      // Effective power = min(60, 100) = 60 kW
      expect(result.effectivePowerKw, equals(60.0));
      // Time = 32.61 / 60 hours = ~33 min
      expect(result.estimatedTimeMinutes, closeTo(33, 2));
      // Cost = 32.61 * 20 = ~₹652
      expect(result.estimatedCost, closeTo(652.0, 10.0));
    });

    test('SmartChargingCalculator handles AC and Ultra Fast efficiency rates correctly', () {
      final acResult = SmartChargingCalculator.calculate(
        currentBatteryPct: 10.0,
        targetBatteryPct: 90.0,
        chargerPowerKw: 22.0,
        vehicleMaxPowerKw: 22.0,
        batteryCapacityKwh: 40.0,
        pricePerKwh: 15.0,
        powerType: 'AC SmartCharge',
      );
      expect(acResult.efficiencyPercentage, equals(90));

      final ultraResult = SmartChargingCalculator.calculate(
        currentBatteryPct: 10.0,
        targetBatteryPct: 90.0,
        chargerPowerKw: 150.0,
        vehicleMaxPowerKw: 150.0,
        batteryCapacityKwh: 75.0,
        pricePerKwh: 25.0,
        powerType: 'Ultra Fast DC',
      );
      expect(ultraResult.efficiencyPercentage, equals(94));
    });

    test('SmartChargingCalculator.parsePrice handles diverse price formats', () {
      expect(SmartChargingCalculator.parsePrice('₹21/kWh'), equals(21.0));
      expect(SmartChargingCalculator.parsePrice('INR 18.5/unit'), equals(18.5));
      expect(SmartChargingCalculator.parsePrice('Free'), equals(21.0)); // fallback
      expect(SmartChargingCalculator.parsePrice(null), equals(21.0));
    });

    test('ChargingSessionModel serialization and status helper test', () {
      final session = ChargingSessionModel(
        id: 'sess_1',
        userId: 'u1',
        stationId: 'st_1',
        chargerId: 'ch_1',
        startTime: DateTime.now(),
        status: SessionStatus.charging,
        currentKw: 55.0,
        unitsConsumed: 12.5,
        currentCost: 262.5,
        batteryPercentage: 45.0,
      );

      final map = session.toMap();
      expect(map['status'], equals('charging'));
      expect(map['currentKw'], equals(55.0));
      expect(map['unitsConsumed'], equals(12.5));

      final copied = session.copyWith(status: SessionStatus.completed, unitsConsumed: 30.0);
      expect(copied.status, equals(SessionStatus.completed));
      expect(copied.unitsConsumed, equals(30.0));
    });
  });
}
