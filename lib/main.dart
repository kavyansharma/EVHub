import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'repositories/firestore_charger_repository.dart';
import 'repositories/hybrid_charger_repository.dart';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // RUNTIME AUDIT BLOCK — prints the full Firestore pipeline to console.
  // Remove this block before shipping to production.
  // ═══════════════════════════════════════════════════════════════════════════
  await _runFirestoreAudit();
  // ═══════════════════════════════════════════════════════════════════════════

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
  final firestoreChargerRepository = FirestoreChargerRepository();
  final hybridChargerRepository = HybridChargerRepository(
    firestoreRepository: firestoreChargerRepository,
    mapsService: mapsService,
  );
  final chargingSessionRepository = ChargingSessionRepository();
  final healthRepository = HealthRepository();
  final subscriptionRepository = SubscriptionRepository();
  final fleetRepository = FleetRepository();
  final ecosystemRepository = EcosystemRepository();
  final maintenanceRepository = MaintenanceRepository();
  final routeAnalyticsRepository = RouteAnalyticsRepository();
  final adminRepository = AdminRepository();

  debugPrint(
    '[main] ✓ All repositories initialized. '
    'Firestore project: ${firestoreChargerRepository.runtimeType}',
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
            firestoreChargerRepository: firestoreChargerRepository,
            hybridChargerRepository: hybridChargerRepository,
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

// ─────────────────────────────────────────────────────────────────────────────
// RUNTIME FIRESTORE AUDIT
// Called once at startup before runApp() to diagnose the Firestore pipeline.
// Remove before shipping to production.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runFirestoreAudit() async {
  // ignore: avoid_print
  void log(String msg) => debugPrint('[RUNTIME-AUDIT] $msg');

  log('═══════════════════════════════════════════════════════');
  log('  FIRESTORE CHARGER PIPELINE AUDIT — START');
  log('═══════════════════════════════════════════════════════');

  // Step 1 — Firebase
  try {
    final app = FirebaseFirestore.instance.app;
    log('Firebase app name    : ${app.name}');
    log('Firebase projectId   : ${app.options.projectId}');
    log('Firebase appId       : ${app.options.appId}');
  } catch (e) {
    log('Firebase NOT initialized: $e');
    return;
  }

  // Step 2 — Firestore fetch
  const String collection = 'chargers';
  log('Collection to fetch  : "$collection"');

  late QuerySnapshot<Map<String, dynamic>> snap;
  try {
    snap = await FirebaseFirestore.instance.collection(collection).get();
    log('Firestore fetch OK   : ${snap.docs.length} documents');
    log('Data from cache      : ${snap.metadata.isFromCache}');
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      log('ROOT CAUSE: Firestore read BLOCKED by security rules (permission-denied)');
    } else {
      log('Firestore FirebaseException: code=${e.code} msg=${e.message}');
    }
    return;
  } catch (e) {
    log('Firestore unexpected error: $e');
    return;
  }

  if (snap.docs.isEmpty) {
    log('ROOT CAUSE: Collection "$collection" is EMPTY — zero chargers in Firestore');
    log('Fix: Add charger documents in Firebase Console');
    return;
  }

  // Step 3 — Per-document audit
  log('──────────────────────────────────────────────────────');
  const double uLat = 28.6304, uLng = 77.2177, radius = 20.0;
  int validGeo = 0, badGeo = 0, keptCount = 0, discardedCount = 0;

  for (int i = 0; i < snap.docs.length; i++) {
    final doc = snap.docs[i];
    final d = doc.data();
    log('Doc [${i + 1}/${snap.docs.length}]: id="${doc.id}"');
    log('  name      : "${d['name']}"');
    log('  status    : "${d['status']}"');
    log('  network   : "${d['network']}"');
    log('  power     : "${d['power']}"');
    log('  connectors: ${d['connectorTypes']}');

    final loc = d['location'];
    if (loc is GeoPoint) {
      validGeo++;
      final lat = loc.latitude, lng = loc.longitude;
      final dLat = (lat - uLat).abs() * 111.0;
      final dLng = (lng - uLng).abs() * 111.0 * 0.85;
      final dist = _auditSqrt(dLat * dLat + dLng * dLng);
      final kept = dist <= radius;
      if (kept) { keptCount++; } else { discardedCount++; }
      log('  location  : GeoPoint($lat, $lng)');
      log('  dist      : ~${dist.toStringAsFixed(2)} km from New Delhi fallback');
      log('  20km-filt : ${kept ? "KEPT" : "DISCARDED (beyond radius)"}');
    } else if (loc == null) {
      badGeo++;
      log('  location  : NULL — field MISSING from document!');
    } else {
      badGeo++;
      log('  location  : WRONG TYPE: ${loc.runtimeType} (expected GeoPoint)');
    }
  }

  // Step 4 — Summary
  log('──────────────────────────────────────────────────────');
  log('Total docs in Firestore    : ${snap.docs.length}');
  log('Valid GeoPoint             : $validGeo');
  log('Missing/bad location       : $badGeo');
  log('Within 20km (kept)         : $keptCount');
  log('Beyond 20km (discarded)    : $discardedCount');
  log('debugShowAllChargers=true  : filter bypassed — all $validGeo should show');

  // Step 5 — Diagnosis
  log('──────────────────────────────────────────────────────');
  if (snap.docs.isEmpty) {
    log('DIAGNOSIS: Firestore empty — zero markers');
  } else if (badGeo == snap.docs.length) {
    log('DIAGNOSIS: ALL docs missing/bad location — zero markers parsed');
  } else if (discardedCount == validGeo && validGeo > 0) {
    log('DIAGNOSIS: All chargers beyond 20km. debugShowAllChargers=true should fix this.');
    log('  If markers still missing, verify the flag is being read at runtime.');
  } else if (validGeo > 0) {
    log('DIAGNOSIS: $validGeo valid chargers found. They should appear on the map.');
    log('  If not visible: check marker icon loading or GoogleMap widget.');
  }
  log('═══════════════════════════════════════════════════════');
  log('  AUDIT COMPLETE');
  log('═══════════════════════════════════════════════════════');
}

double _auditSqrt(double x) {
  if (x <= 0) return 0;
  double g = x / 2;
  for (int i = 0; i < 20; i++) {
    g = (g + x / g) / 2;
  }
  return g;
}

