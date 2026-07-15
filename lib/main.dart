import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'firebase/firebase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/station_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/wallet_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/station_repository.dart';
import 'repositories/trip_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/wallet_repository.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

import 'repositories/garage_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/analytics_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/assistant_repository.dart';
import 'repositories/reservation_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/reward_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/maps_repository.dart';
import 'repositories/charging_session_repository.dart';
import 'repositories/health_repository.dart';
import 'repositories/subscription_repository.dart';
import 'repositories/fleet_repository.dart';
import 'repositories/ecosystem_repository.dart';
import 'repositories/maintenance_repository.dart';
import 'repositories/route_analytics_repository.dart';
import 'repositories/admin_repository.dart';

import 'services/vehicle_service.dart';
import 'services/battery_health_service.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/ai_service.dart';
import 'services/reservation_service.dart';
import 'services/review_service.dart';
import 'services/reward_service.dart';
import 'services/profile_service.dart';
import 'services/maps_service.dart';
import 'services/charging_session_service.dart';
import 'services/health_service.dart';
import 'services/directions_service.dart';
import 'services/subscription_service.dart';
import 'services/fleet_service.dart';
import 'services/ecosystem_service.dart';
import 'services/maintenance_service.dart';
import 'services/route_analytics_service.dart';
import 'services/admin_service.dart';

import 'providers/garage_provider.dart';
import 'providers/history_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/battery_provider.dart';
import 'providers/assistant_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/reservation_provider.dart';
import 'providers/review_provider.dart';
import 'providers/reward_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/maps_provider.dart';
import 'providers/charging_session_provider.dart';
import 'providers/health_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/fleet_provider.dart';
import 'providers/ecosystem_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/route_analytics_provider.dart';
import 'providers/admin_provider.dart';

void main() async {
  // Ensure Flutter engine bindings are ready before initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase First!
  try {
    await FirebaseService.initialize();
  } catch (e, stack) {
    debugPrint("Firebase init failed: $e");
    debugPrintStack(stackTrace: stack);
  }
  // 1. Initialize core persistence and network services
  final storageService = await StorageService.init();

  // 2. Initialize repositories
  final userRepository = UserRepositoryImpl();
  final stationRepository = StationRepositoryImpl();
  final tripRepository = TripRepositoryImpl();
  final walletRepository = WalletRepositoryImpl();
  
  final authRepository = AuthRepositoryImpl(
    authService: AuthService(),
    storageService: storageService,
    userRepository: userRepository,
  );

  // Phase 3 Services
  final vehicleService = VehicleService();
  final batteryHealthService = BatteryHealthService();
  final analyticsService = AnalyticsService();
  final notificationService = NotificationService();
  final aiService = AIService();
  final reservationService = ReservationService();
  final reviewService = ReviewService();
  final rewardService = RewardService();
  final profileService = ProfileService();
  final mapsService = MapsService();
  final chargingSessionService = ChargingSessionService();
  final healthService = HealthService();
  final directionsService = DirectionsService();
  final subscriptionService = SubscriptionService();
  final fleetService = FleetService();
  final ecosystemService = EcosystemService();
  final maintenanceService = MaintenanceService();
  final routeAnalyticsService = RouteAnalyticsService();
  final adminService = AdminService();

  // Phase 3, 4 & 5 Repositories
  final garageRepository = GarageRepository();
  final historyRepository = HistoryRepository();
  final analyticsRepository = AnalyticsRepository();
  final notificationRepository = NotificationRepository(notificationService: notificationService);
  final assistantRepository = AssistantRepository(aiService: aiService);
  final reservationRepository = ReservationRepository();
  final reviewRepository = ReviewRepository();
  final rewardRepository = RewardRepository();
  final profileRepository = ProfileRepository();
  final mapsRepository = MapsRepository(mapsService: mapsService);
  final chargingSessionRepository = ChargingSessionRepository();
  final healthRepository = HealthRepository();
  final subscriptionRepository = SubscriptionRepository();
  final fleetRepository = FleetRepository();
  final ecosystemRepository = EcosystemRepository();
  final maintenanceRepository = MaintenanceRepository();
  final routeAnalyticsRepository = RouteAnalyticsRepository();
  final adminRepository = AdminRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authRepository: authRepository,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StationProvider(stationRepository: stationRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => TripProvider(
            tripRepository: tripRepository,
            directionsService: directionsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletProvider(walletRepository: walletRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => GarageProvider(
            garageRepository: garageRepository,
            vehicleService: vehicleService,
          )..loadEcosystemVehicles(),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(historyRepository: historyRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(
            analyticsRepository: analyticsRepository,
            analyticsService: analyticsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BatteryProvider(batteryHealthService: batteryHealthService),
        ),
        ChangeNotifierProvider(
          create: (_) => AssistantProvider(assistantRepository: assistantRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(notificationRepository: notificationRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ReservationProvider(
            reservationRepository: reservationRepository,
            reservationService: reservationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewProvider(
            reviewRepository: reviewRepository,
            reviewService: reviewService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RewardProvider(
            rewardRepository: rewardRepository,
            rewardService: rewardService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            profileRepository: profileRepository,
            profileService: profileService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MapsProvider(
            mapsRepository: mapsRepository,
            mapsService: mapsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChargingSessionProvider(
            repository: chargingSessionRepository,
            service: chargingSessionService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HealthProvider(
            repository: healthRepository,
            service: healthService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(
            repository: subscriptionRepository,
            service: subscriptionService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FleetProvider(
            repository: fleetRepository,
            service: fleetService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => EcosystemProvider(
            repository: ecosystemRepository,
            service: ecosystemService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MaintenanceProvider(
            repository: maintenanceRepository,
            service: maintenanceService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RouteAnalyticsProvider(
            repository: routeAnalyticsRepository,
            service: routeAnalyticsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminProvider(
            repository: adminRepository,
            service: adminService,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'EVHub',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme(themeProvider.currentBrandColor),
      darkTheme: AppTheme.darkTheme(themeProvider.currentBrandColor),
      home: const SplashScreen(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
