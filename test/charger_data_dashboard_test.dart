import 'package:flutter_test/flutter_test.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/user_model.dart';
import 'package:evhub/providers/charger_data_dashboard_provider.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';

class MockFirestoreChargerRepository implements FirestoreChargerRepository {
  List<MapMarkerModel> mockChargers = [];
  bool shouldFail = false;

  @override
  Future<List<MapMarkerModel>> getAllChargers() async {
    if (shouldFail) {
      throw Exception('Firestore fetch error');
    }
    return mockChargers;
  }

  @override
  Stream<List<MapMarkerModel>> streamAllChargers() => Stream.value(mockChargers);

  @override
  Future<void> addCharger(MapMarkerModel charger) async {}

  @override
  Future<void> updateCharger(MapMarkerModel charger) async {}

  @override
  Future<void> deleteCharger(String chargerId) async {}

  @override
  Future<void> approveCharger(String chargerId, String adminId) async {}

  @override
  Future<void> rejectCharger(String chargerId, String adminId) async {}

  @override
  Future<List<MapMarkerModel>> getChargersByOwner(String ownerId) async => mockChargers;

  @override
  Stream<List<MapMarkerModel>> streamChargersByOwner(String ownerId) => Stream.value(mockChargers);

  @override
  Future<List<MapMarkerModel>> getPublicVerifiedChargers() async => mockChargers;

  @override
  Future<MapMarkerModel?> getChargerById(String id) async => null;

  @override
  Future<List<MapMarkerModel>> getPendingChargers() async => mockChargers;

  @override
  Stream<List<MapMarkerModel>> streamPublicVerifiedChargers() => Stream.value(mockChargers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EVHub Phase 7.4A — Charger Data Operations Dashboard Tests', () {
    late MockFirestoreChargerRepository mockRepo;
    late ChargerDataDashboardProvider provider;

    final adminUser = const UserModel(
      id: 'admin_1',
      email: 'admin@evhub.com',
      name: 'EVHub Operations Admin',
      role: Role.admin,
    );

    final normalUser = const UserModel(
      id: 'user_1',
      email: 'driver@evhub.com',
      name: 'Driver',
      role: Role.user,
    );

    setUp(() {
      mockRepo = MockFirestoreChargerRepository();
      provider = ChargerDataDashboardProvider(firestoreRepository: mockRepo);
    });

    test('1. Total charger count calculation', () async {
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'Tata CP', description: 'CP', latitude: 28.63, longitude: 77.21, type: MarkerType.station, network: 'Tata Power', isVerified: true),
        const MapMarkerModel(id: 'c2', title: 'Statiq Hub', description: 'Gurgaon', latitude: 28.45, longitude: 77.02, type: MarkerType.station, network: 'Statiq', isVerified: true),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      expect(provider.totalVerifiedChargers, equals(2));
    });

    test('2, 3, 4, 5. Available, Busy, Offline, Unknown status counts', () async {
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'Available', description: 'CP', latitude: 28.63, longitude: 77.21, type: MarkerType.station, status: MarkerStatus.available),
        const MapMarkerModel(id: 'c2', title: 'Busy', description: 'Gurgaon', latitude: 28.45, longitude: 77.02, type: MarkerType.station, status: MarkerStatus.busy),
        const MapMarkerModel(id: 'c3', title: 'Offline', description: 'Noida', latitude: 28.53, longitude: 77.39, type: MarkerType.station, status: MarkerStatus.offline),
        const MapMarkerModel(id: 'c4', title: 'Unknown', description: 'Delhi', latitude: 28.60, longitude: 77.20, type: MarkerType.station, status: MarkerStatus.unknown),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      expect(provider.availableChargers, equals(1));
      expect(provider.busyChargers, equals(1));
      expect(provider.offlineChargers, equals(1));
      expect(provider.unknownAvailabilityChargers, equals(1));
      expect(provider.totalActiveChargers, equals(2)); // Available + Busy
    });

    test('6. Network aggregation & descending count sorting', () async {
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'S1', description: 'A1', latitude: 28.6, longitude: 77.2, type: MarkerType.station, network: 'Tata Power'),
        const MapMarkerModel(id: 'c2', title: 'S2', description: 'A2', latitude: 28.6, longitude: 77.2, type: MarkerType.station, network: 'Statiq'),
        const MapMarkerModel(id: 'c3', title: 'S3', description: 'A3', latitude: 28.6, longitude: 77.2, type: MarkerType.station, network: 'Tata Power'),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      final breakdown = provider.networkBreakdown;
      expect(breakdown.length, equals(2));
      expect(breakdown.first.networkName, equals('Tata Power'));
      expect(breakdown.first.count, equals(2));
      expect(breakdown.first.percentage, closeTo(66.6, 0.5));
    });

    test('7 & 8. City and State aggregation & Top 10 listing', () async {
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'S1', description: 'A1', latitude: 28.6, longitude: 77.2, type: MarkerType.station, city: 'New Delhi', state: 'Delhi'),
        const MapMarkerModel(id: 'c2', title: 'S2', description: 'A2', latitude: 28.6, longitude: 77.2, type: MarkerType.station, city: 'New Delhi', state: 'Delhi'),
        const MapMarkerModel(id: 'c3', title: 'S3', description: 'A3', latitude: 28.4, longitude: 77.0, type: MarkerType.station, city: 'Gurgaon', state: 'Haryana'),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      final coverage = provider.locationCoverage;

      expect(coverage.totalCities, equals(2));
      expect(coverage.totalStates, equals(2));
      expect(coverage.topCities.first.name, equals('New Delhi'));
      expect(coverage.topCities.first.count, equals(2));
      expect(coverage.topStates.first.name, equals('Delhi'));
    });

    test('9 & 10. Connector availability calculation & zero connector division safety', () async {
      // Zero connectors case
      mockRepo.mockChargers = [];
      await provider.refreshDashboard(currentUser: adminUser);
      expect(provider.availabilityHealth.connectorAvailabilityPercentage, equals(0.0));

      // With connectors case
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'S1', description: 'A1', latitude: 28.6, longitude: 77.2, type: MarkerType.station, connectorCount: 4, availableStalls: '3/4'),
        const MapMarkerModel(id: 'c2', title: 'S2', description: 'A2', latitude: 28.4, longitude: 77.0, type: MarkerType.station, connectorCount: 6, availableStalls: '2/6'),
      ];
      await provider.refreshDashboard(currentUser: adminUser);
      final avail = provider.availabilityHealth;

      expect(avail.totalConnectors, equals(10));
      expect(avail.availableConnectors, equals(5));
      expect(avail.occupiedConnectors, equals(5));
      expect(avail.connectorAvailabilityPercentage, equals(50.0));
    });

    test('11 & 12. Missing field detection & Data Quality Score formula', () async {
      mockRepo.mockChargers = [
        // Perfect charger (8/8 required fields)
        const MapMarkerModel(
          id: 'c1',
          title: 'Complete Charger',
          description: 'Full Address',
          latitude: 28.63,
          longitude: 77.21,
          type: MarkerType.station,
          network: 'Tata Power',
          city: 'New Delhi',
          state: 'Delhi',
          country: 'India',
          power: '150kW',
        ),
        // Incomplete charger (missing city, state, country)
        const MapMarkerModel(
          id: 'c2',
          title: 'Incomplete Charger',
          description: 'Street 1',
          latitude: 28.63,
          longitude: 77.21,
          type: MarkerType.station,
          network: 'Statiq',
          power: '60kW',
        ),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      final dq = provider.dataQualityHealth;

      expect(dq.totalChargers, equals(2));
      expect(dq.missingCity, equals(1));
      expect(dq.missingState, equals(1));
      expect(dq.missingCountry, equals(1));

      // Required fields = 2 * 8 = 16 total. Charger 1 has 8, Charger 2 has 5. Valid = 13/16 = 81.25%
      expect(dq.score, closeTo(81.25, 0.1));
      expect(dq.ratingTier, equals('Good'));
    });

    test('13 & 14. Stale charger detection & Missing timestamp handling', () async {
      final now = DateTime.now();
      final freshDate = now.subtract(const Duration(days: 5));
      final staleDate = now.subtract(const Duration(days: 45));

      mockRepo.mockChargers = [
        MapMarkerModel(id: 'c1', title: 'Fresh', description: 'A1', latitude: 28.6, longitude: 77.2, type: MarkerType.station, updatedAt: freshDate),
        MapMarkerModel(id: 'c2', title: 'Stale', description: 'A2', latitude: 28.6, longitude: 77.2, type: MarkerType.station, updatedAt: staleDate),
        const MapMarkerModel(id: 'c3', title: 'Never Updated', description: 'A3', latitude: 28.6, longitude: 77.2, type: MarkerType.station), // no timestamp
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      final stale = provider.staleDataStats;

      expect(stale.freshCount, equals(1));
      expect(stale.staleCount, equals(1));
      expect(stale.neverUpdatedCount, equals(1));
    });

    test('15 & 16. Recent charger sorting (createdAt & updatedAt)', () async {
      final dtOld = DateTime(2026, 1, 10);
      final dtNew = DateTime(2026, 1, 20);

      mockRepo.mockChargers = [
        MapMarkerModel(id: 'c_old', title: 'Old Charger', description: 'A1', latitude: 28.6, longitude: 77.2, type: MarkerType.station, createdAt: dtOld, updatedAt: dtOld),
        MapMarkerModel(id: 'c_new', title: 'New Charger', description: 'A2', latitude: 28.6, longitude: 77.2, type: MarkerType.station, createdAt: dtNew, updatedAt: dtNew),
      ];

      await provider.refreshDashboard(currentUser: adminUser);

      final added = provider.recentlyAddedChargers;
      final updated = provider.recentlyUpdatedChargers;

      expect(added.first.id, equals('c_new'));
      expect(updated.first.id, equals('c_new'));
    });

    test('17. Empty Firestore dataset handling', () async {
      mockRepo.mockChargers = [];
      await provider.refreshDashboard(currentUser: adminUser);

      expect(provider.totalVerifiedChargers, equals(0));
      expect(provider.networkBreakdown, isEmpty);
      expect(provider.locationCoverage.totalCities, equals(0));
      expect(provider.dataQualityHealth.score, equals(0.0));
      expect(provider.dataQualityHealth.ratingTier, equals('N/A'));
    });

    test('18. Firestore fetch failure handling', () async {
      mockRepo.shouldFail = true;
      await provider.refreshDashboard(currentUser: adminUser);

      expect(provider.errorMessage, contains('Firestore fetch error'));
      expect(provider.isLoading, isFalse);
    });

    test('19. Invalid GeoPoint coordinates handling in Data Quality', () async {
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'Bad Geo', description: 'A1', latitude: 999.0, longitude: 77.2, type: MarkerType.station),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      expect(provider.dataQualityHealth.missingGeoPoint, equals(1));
    });

    test('20. Unknown network handling in Network Breakdown', () async {
      mockRepo.mockChargers = [
        const MapMarkerModel(id: 'c1', title: 'Station 1', description: 'A1', latitude: 28.6, longitude: 77.2, type: MarkerType.station, network: ''),
      ];

      await provider.refreshDashboard(currentUser: adminUser);
      final net = provider.networkBreakdown.first;
      expect(net.networkName, equals('Unknown Network'));
      expect(net.count, equals(1));
    });

    test('21. Non-admin access restriction', () async {
      await provider.refreshDashboard(currentUser: normalUser);
      expect(provider.errorMessage, contains('admin profile could not be loaded'));
      expect(provider.chargers, isEmpty);
    });
  });
}
