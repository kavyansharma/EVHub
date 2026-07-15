import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
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

import 'services/vehicle_service.dart';
import 'services/battery_health_service.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/ai_service.dart';

import 'providers/garage_provider.dart';
import 'providers/history_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/battery_provider.dart';
import 'providers/assistant_provider.dart';
import 'providers/notification_provider.dart';

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

  // Phase 3 Repositories
  final garageRepository = GarageRepository();
  final historyRepository = HistoryRepository();
  final analyticsRepository = AnalyticsRepository();
  final notificationRepository = NotificationRepository(notificationService: notificationService);
  final assistantRepository = AssistantRepository(aiService: aiService);

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
          create: (_) => TripProvider(tripRepository: tripRepository),
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'EVHub',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
