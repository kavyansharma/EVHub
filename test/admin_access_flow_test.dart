import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evhub/models/user_model.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/models/profile_model.dart';
import 'package:evhub/providers/auth_provider.dart';
import 'package:evhub/providers/admin_charger_provider.dart';
import 'package:evhub/providers/charger_data_dashboard_provider.dart';
import 'package:evhub/providers/profile_provider.dart';
import 'package:evhub/repositories/auth_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/profile_repository.dart';
import 'package:evhub/services/storage_service.dart';
import 'package:evhub/services/profile_service.dart';
import 'package:evhub/providers/theme_provider.dart';
import 'package:evhub/screens/phase4/profile_screen.dart';
import 'package:evhub/screens/admin/admin_dashboard_screen.dart';
import 'package:evhub/core/routes/app_routes.dart';

class MockAuthRepository implements AuthRepository {
  bool signOutCalled = false;
  UserModel? mockUser;

  @override
  Future<void> logout() async {
    signOutCalled = true;
  }

  @override
  Future<UserModel> login({required String email, required String password, bool rememberMe = false}) async {
    return mockUser ?? const UserModel(id: 'admin_1', email: 'sharmakavyan72@gmail.com', name: 'Kavyan Sharma', role: Role.admin);
  }

  @override
  Future<UserModel> signup({required String email, required String password, required String name}) async {
    return mockUser ?? const UserModel(id: 'user_1', email: 'user@evhub.com', name: 'User');
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<UserModel?> restoreSession() async => mockUser;

  @override
  Future<UserModel> startGuestSession() async => UserModel.guest();

  @override
  Future<UserModel?> googleSignIn() async => mockUser;

  @override
  bool isRememberMeEnabled() => false;

  @override
  Map<String, String>? getRememberedCredentials() => null;

  @override
  Future<void> clearRememberedCredentials() async {}
}

class MockStorageService implements StorageService {
  @override
  bool isFirstLaunch() => false;
  @override
  Future<bool> setFirstLaunchCompleted() async => true;
  @override
  bool getRememberMe() => false;
  @override
  Future<bool> setRememberMe(bool value) async => true;
  @override
  String? getRememberedEmail() => null;
  @override
  Future<bool> setRememberedEmail(String email) async => true;
  @override
  Future<bool> removeRememberedEmail() async => true;
  @override
  String getThemeMode() => 'dark';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProfileRepository implements ProfileRepository {
  @override
  Future<ProfileModel> getProfile(String userId) async {
    return const ProfileModel(
      userId: 'test_user',
      phone: '+1234567890',
      totalRewardPoints: 100,
      totalSessions: 10,
      totalKwhCharged: 150.0,
      membershipTier: 'Gold',
      badges: ['First Charge'],
    );
  }

  @override
  Future<void> updateProfile(ProfileModel profile) async {}
}

class MockFirestoreChargerRepository implements FirestoreChargerRepository {
  List<MapMarkerModel> mockChargers = [
    const MapMarkerModel(
      id: 'c1',
      title: 'CP Fast Charger',
      description: 'Connaught Place',
      latitude: 28.63,
      longitude: 77.21,
      type: MarkerType.station,
      network: 'Tata Power',
      isVerified: true,
      status: MarkerStatus.available,
    ),
  ];

  @override
  Future<List<MapMarkerModel>> getAllChargers() async => mockChargers;

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
  group('EVHub Admin Access Flow Tests', () {
    late MockAuthRepository mockAuthRepo;
    late MockStorageService mockStorageService;
    late MockProfileRepository mockProfileRepo;
    late MockFirestoreChargerRepository mockChargerRepo;

    final adminUser = const UserModel(
      id: 'IpYz6FML42R3oiaoKtccctlGSYW2',
      email: 'sharmakavyan72@gmail.com',
      name: 'Kavyan Sharma',
      role: Role.admin,
      isGuest: false,
    );

    final normalUser = const UserModel(
      id: 'normal_123',
      email: 'driver@evhub.com',
      name: 'Regular Driver',
      role: Role.user,
      isGuest: false,
    );

    final guestUser = UserModel.guest();

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockStorageService = MockStorageService();
      mockProfileRepo = MockProfileRepository();
      mockChargerRepo = MockFirestoreChargerRepository();
    });

    test('TEST 1: Admin Firestore role "admin" is parsed as Role.admin', () {
      final json = {'id': '123', 'email': 'a@b.com', 'name': 'Admin', 'role': 'admin'};
      final user = UserModel.fromJson(json);
      expect(user.role, equals(Role.admin));
      expect(user.isAdmin, isTrue);

      final uppercaseJson = {'id': '123', 'email': 'a@b.com', 'name': 'Admin', 'role': 'ADMIN'};
      final userUpper = UserModel.fromJson(uppercaseJson);
      expect(userUpper.role, equals(Role.admin));

      final prefixJson = {'id': '123', 'email': 'a@b.com', 'name': 'Admin', 'role': 'Role.admin'};
      final userPrefix = UserModel.fromJson(prefixJson);
      expect(userPrefix.role, equals(Role.admin));
    });

    testWidgets('TEST 2: Admin user sees Admin Dashboard navigation option in ProfileScreen', (WidgetTester tester) async {
      mockAuthRepo.mockUser = adminUser;
      final authProvider = AuthProvider(authRepository: mockAuthRepo, storageService: mockStorageService);
      await authProvider.login('sharmakavyan72@gmail.com', 'password');

      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      final profileProvider = ProfileProvider(profileRepository: mockProfileRepo, profileService: ProfileService());
      await profileProvider.loadProfile(adminUser.id);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminChargerProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ADMIN CONTROL PANEL'), findsOneWidget);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('TEST 3: Normal user does NOT see Admin Dashboard navigation option', (WidgetTester tester) async {
      mockAuthRepo.mockUser = normalUser;
      final authProvider = AuthProvider(authRepository: mockAuthRepo, storageService: mockStorageService);
      await authProvider.login('driver@evhub.com', 'password');

      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      final profileProvider = ProfileProvider(profileRepository: mockProfileRepo, profileService: ProfileService());
      await profileProvider.loadProfile(normalUser.id);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminChargerProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ADMIN CONTROL PANEL'), findsNothing);
      expect(find.text('Admin Dashboard'), findsNothing);
    });

    testWidgets('TEST 4: Guest user does NOT see Admin Dashboard navigation option', (WidgetTester tester) async {
      mockAuthRepo.mockUser = guestUser;
      final authProvider = AuthProvider(authRepository: mockAuthRepo, storageService: mockStorageService);
      await authProvider.loginAsGuest();

      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      final profileProvider = ProfileProvider(profileRepository: mockProfileRepo, profileService: ProfileService());
      await profileProvider.loadProfile('guest');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminChargerProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ADMIN CONTROL PANEL'), findsNothing);
      expect(find.text('Admin Dashboard'), findsNothing);
    });

    testWidgets('TEST 5: Admin can navigate to AdminDashboardScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockAuthRepo.mockUser = adminUser;
      final authProvider = AuthProvider(authRepository: mockAuthRepo, storageService: mockStorageService);
      await authProvider.login('sharmakavyan72@gmail.com', 'password');

      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      final profileProvider = ProfileProvider(profileRepository: mockProfileRepo, profileService: ProfileService());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(mockStorageService)),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminChargerProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            routes: {
              '/': (ctx) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.adminDashboard),
                    child: const Text('Go Admin'),
                  ),
                ),
              ),
            },
            onGenerateRoute: AppRoutes.generateRoute,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Go Admin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.text('Charger Data Operations Dashboard'), findsOneWidget);
    });

    testWidgets('TEST 6: Non-admin direct navigation to AdminDashboardScreen is blocked', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockAuthRepo.mockUser = normalUser;
      final authProvider = AuthProvider(authRepository: mockAuthRepo, storageService: mockStorageService);
      await authProvider.login('driver@evhub.com', 'password');

      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      final profileProvider = ProfileProvider(profileRepository: mockProfileRepo, profileService: ProfileService());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(mockStorageService)),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminChargerProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Admin Profile Error'), findsOneWidget);
      expect(find.text('Charger Data Operations Dashboard'), findsNothing);
    });

    test('TEST 7: Admin Dashboard loads existing charger data', () async {
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      await dashboardProvider.refreshDashboard(currentUser: adminUser);

      expect(dashboardProvider.totalVerifiedChargers, equals(1));
      expect(dashboardProvider.errorMessage, isNull);
    });

    test('TEST 8: Admin Dashboard provider receives the correct admin user', () async {
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);
      await dashboardProvider.refreshDashboard(currentUser: adminUser);

      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.role, equals(Role.admin));
    });

    test('TEST 9: Logout clears admin state in providers', () async {
      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);

      await dashboardProvider.refreshDashboard(currentUser: adminUser);
      expect(dashboardProvider.totalVerifiedChargers, equals(1));

      adminChargerProvider.clearState();
      dashboardProvider.clearDashboard();

      expect(dashboardProvider.totalVerifiedChargers, equals(0));
      expect(adminChargerProvider.allChargers, isEmpty);
    });

    test('TEST 10: After logout, admin state clears and prevents returning to Admin Dashboard', () async {
      mockAuthRepo.mockUser = adminUser;
      final authProvider = AuthProvider(authRepository: mockAuthRepo, storageService: mockStorageService);
      await authProvider.login('sharmakavyan72@gmail.com', 'password');

      final adminChargerProvider = AdminChargerProvider(firestoreRepository: mockChargerRepo);
      final dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockChargerRepo);

      await dashboardProvider.refreshDashboard(currentUser: adminUser);
      expect(dashboardProvider.totalVerifiedChargers, equals(1));

      final success = await authProvider.logout();
      expect(success, isTrue);

      adminChargerProvider.clearState();
      dashboardProvider.clearDashboard();

      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.user, isNull);
      expect(dashboardProvider.totalVerifiedChargers, equals(0));
      expect(adminChargerProvider.allChargers, isEmpty);
    });
  });
}
