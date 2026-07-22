import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Central Firebase initialization service.
/// Call [FirebaseService.initialize] once in main() before runApp().
class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── DEBUG: confirm which Firebase project is connected ──────────────────
    debugPrint(
      '[Firebase] ✓ Initialized successfully. '
      'Active projectId: ${DefaultFirebaseOptions.currentPlatform.projectId}',
    );

    // Enable Firestore offline persistence for web and mobile.
    // This allows the app to work offline with cached data.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[Firebase] Firestore offline persistence enabled.');
    } catch (e) {
      // Persistence may already be enabled (hot restart scenario).
      debugPrint('[Firebase] Firestore persistence note: $e');
    }
  }
}
