// ============================================================
// firebase_options.dart — AUTO-GENERATED TEMPLATE
// Replace placeholder values with your actual Firebase project
// configuration from: Firebase Console → Project Settings → General
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Web Firebase configuration.
  /// Replace all values with your real Firebase project credentials.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCEo5B22e8tT6UUIMgI8BA_jXLdLMQsmAg',
    appId: '1:211167795372:web:c41d97ccea2abe04fe6709',
    messagingSenderId: '211167795372',
    projectId: 'evhub-9e25f',
    authDomain: 'evhub-9e25f.firebaseapp.com',
    storageBucket: 'evhub-9e25f.firebasestorage.app',
    measurementId: 'G-1QT3R9G61B',
  );

  /// Android Firebase configuration (if needed).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCEo5B22e8tT6UUIMgI8BA_jXLdLMQsmAg',
    appId: '1:211167795372:android:cad61d54242d6f41fe6709',
    messagingSenderId: '211167795372',
    projectId: 'evhub-9e25f',
    storageBucket: 'evhub-9e25f.firebasestorage.app',
  );

  /// iOS Firebase configuration (if needed).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCEo5B22e8tT6UUIMgI8BA_jXLdLMQsmAg',
    appId: '1:211167795372:ios:71e31f7e10af619bfe6709',
    messagingSenderId: '211167795372',
    projectId: 'evhub-9e25f',
    storageBucket: 'evhub-9e25f.firebasestorage.app',
    iosBundleId: 'com.evhub.evhub',
  );
}
