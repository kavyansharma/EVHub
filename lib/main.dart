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
