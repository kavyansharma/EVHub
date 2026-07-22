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
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );

  /// iOS Firebase configuration (if needed).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'com.evhub.app',
  );
}
