import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evhub/models/user_model.dart';
import 'package:evhub/models/map_marker_model.dart';
import 'package:evhub/providers/auth_provider.dart';
import 'package:evhub/providers/admin_charger_provider.dart';
import 'package:evhub/providers/charger_data_dashboard_provider.dart';
import 'package:evhub/providers/profile_provider.dart';
import 'package:evhub/repositories/auth_repository.dart';
import 'package:evhub/repositories/firestore_charger_repository.dart';
import 'package:evhub/repositories/profile_repository.dart';
import 'package:evhub/services/storage_service.dart';
import 'package:evhub/services/profile_service.dart';
import 'package:evhub/models/profile_model.dart';
import 'package:evhub/screens/phase4/profile_screen.dart';
import 'package:evhub/core/routes/app_routes.dart';

class MockAuthRepository implements AuthRepository {
  bool signOutCalled = false;
  bool shouldFail = false;
  UserModel? mockUser;

  @override
  Future<void> logout() async {
    signOutCalled = true;
    if (shouldFail) {
      throw Exception('Firebase signOut error');
    }
  }

  @override
  Future<UserModel> login({required String email, required String password, bool rememberMe = false}) async {
    return mockUser ?? const UserModel(id: 'admin_1', email: 'admin@evhub.com', name: 'Admin', role: Role.admin);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockProfileRepository implements ProfileRepository {
  @override
  Future<ProfileModel> getProfile(String userId) async {
    return const ProfileModel(
      userId: 'admin_1',
      phone: '+1234567890',
      totalRewardPoints: 100,
      totalSessions: 12,
      totalKwhCharged: 250.0,
      membershipTier: 'Platinum',
      badges: ['Early Adopter'],
    );
  }

  @override
  Future<void> updateProfile(ProfileModel profile) async {}
}

class MockFirestoreChargerRepository implements FirestoreChargerRepository {
  List<MapMarkerModel> mockChargers = [];
  bool shouldFail = false;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EVHub Production Logout Functionality Tests', () {
    late MockAuthRepository mockAuthRepo;
    late MockStorageService mockStorageService;
    late MockFirestoreChargerRepository mockFirestoreRepo;
    late AuthProvider authProvider;
    late AdminChargerProvider adminProvider;
    late ChargerDataDashboardProvider dashboardProvider;
    late ProfileProvider profileProvider;

    final adminUser = const UserModel(
      id: 'admin_1',
      email: 'admin@evhub.com',
      name: 'EVHub Admin',
      role: Role.admin,
    );

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockStorageService = MockStorageService();
      mockFirestoreRepo = MockFirestoreChargerRepository();
      authProvider = AuthProvider(
        authRepository: mockAuthRepo,
        storageService: mockStorageService,
      );
      adminProvider = AdminChargerProvider(firestoreRepository: mockFirestoreRepo);
      dashboardProvider = ChargerDataDashboardProvider(firestoreRepository: mockFirestoreRepo);
      profileProvider = ProfileProvider(
        profileRepository: MockProfileRepository(),
        profileService: ProfileService(),
      );
    });

    test('1. AuthProvider.logout() calls AuthRepository.logout() and clears user state', () async {
      mockAuthRepo.mockUser = adminUser;
      await authProvider.login('admin@evhub.com', 'pass123');
      expect(authProvider.isAuthenticated, isTrue);

      final success = await authProvider.logout();

      expect(mockAuthRepo.signOutCalled, isTrue);
      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.user, isNull);
    });

    test('2. Logout failure is handled gracefully without app crash', () async {
      mockAuthRepo.mockUser = adminUser;
      await authProvider.login('admin@evhub.com', 'pass123');
      mockAuthRepo.shouldFail = true;

      final success = await authProvider.logout();

      expect(mockAuthRepo.signOutCalled, isTrue);
      expect(success, isFalse);
      expect(authProvider.errorMessage, contains('Firebase signOut error'));
    });

    test('3. AdminChargerProvider & ChargerDataDashboardProvider state clearing', () {
      adminProvider.clearState();
      dashboardProvider.clearDashboard();

      expect(adminProvider.allChargers, isEmpty);
      expect(adminProvider.chargers, isEmpty);
      expect(dashboardProvider.chargers, isEmpty);
    });

    testWidgets('4. Logout confirmation dialog rendering & Cancel behavior', (WidgetTester tester) async {
      mockAuthRepo.mockUser = adminUser;
      await authProvider.login('admin@evhub.com', 'pass123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            onGenerateRoute: AppRoutes.generateRoute,
            home: const Scaffold(
              body: Center(child: Text('Profile Area')),
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('Profile Area'));
      
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout of EVHub?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Logout'), findsWidgets);
      expect(find.text('Are you sure you want to logout of EVHub?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Are you sure you want to logout of EVHub?'), findsNothing);
      expect(authProvider.isAuthenticated, isTrue);
      expect(mockAuthRepo.signOutCalled, isFalse);
    });

    testWidgets('5. Confirming logout calls signOut and navigate to Login removing stack', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuthRepo.mockUser = adminUser;
      await authProvider.login('admin@evhub.com', 'pass123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<AdminChargerProvider>.value(value: adminProvider),
            ChangeNotifierProvider<ChargerDataDashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            routes: {
              '/': (context) => const ProfileScreen(),
              AppRoutes.login: (context) => const Scaffold(body: Text('Login Screen Landmark')),
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final logoutButton = find.byKey(const Key('logout_button'));
      expect(logoutButton, findsOneWidget);

      await tester.tap(logoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Logout'), findsWidgets);
      expect(find.text('Are you sure you want to logout of EVHub?'), findsOneWidget);

      // Tap Confirm Logout in dialog
      final confirmLogoutButton = find.widgetWithText(ElevatedButton, 'Logout');
      await tester.tap(confirmLogoutButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(mockAuthRepo.signOutCalled, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      expect(find.text('Login Screen Landmark'), findsOneWidget);
    });
  });
}
