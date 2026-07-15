// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';

class LoggerService {
  static void debug(String message) {
    if (kDebugMode) {
      print('🐛 [DEBUG] $message');
    }
  }

  static void info(String message) {
    print('ℹ️ [INFO] $message');
  }

  static void warning(String message) {
    print('⚠️ [WARNING] $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    print('🚨 [ERROR] $message');
    if (error != null) {
      print('Details: $error');
    }
    if (stackTrace != null) {
      print(stackTrace);
    }
  }
}
