import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Local persistence service (SharedPreferences).
/// Handles: theme, onboarding, remember-me credentials.
/// Firebase Auth now owns the user session — no user JSON stored here.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Theme Configuration ---
  String getThemeMode() {
    return _prefs.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  Future<bool> setThemeMode(String theme) async {
    return await _prefs.setString(AppConstants.keyThemeMode, theme);
  }

  // --- Onboarding Completion Status ---
  bool isFirstLaunch() {
    return _prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
  }

  Future<bool> setFirstLaunchCompleted() async {
    return await _prefs.setBool(AppConstants.keyFirstLaunch, false);
  }

  // --- Remember Me (stores email only, never password) ---
  bool getRememberMe() {
    return _prefs.getBool(AppConstants.keyRememberMe) ?? false;
  }

  Future<bool> setRememberMe(bool value) async {
    return await _prefs.setBool(AppConstants.keyRememberMe, value);
  }

  String? getRememberedEmail() {
    return _prefs.getString(AppConstants.keyRememberedEmail);
  }

  Future<bool> setRememberedEmail(String email) async {
    return await _prefs.setString(AppConstants.keyRememberedEmail, email);
  }

  Future<bool> removeRememberedEmail() async {
    return await _prefs.remove(AppConstants.keyRememberedEmail);
  }

  /// Clears all preferences except theme and first-launch state.
  Future<void> clearAll() async {
    final theme = getThemeMode();
    final firstLaunch = isFirstLaunch();
    await _prefs.clear();
    await setThemeMode(theme);
    if (!firstLaunch) {
      await setFirstLaunchCompleted();
    }
  }
}
