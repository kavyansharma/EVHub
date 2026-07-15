import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

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

  // --- Remember Login State ---
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

  String? getRememberedPassword() {
    return _prefs.getString(AppConstants.keyRememberedPassword);
  }

  Future<bool> setRememberedPassword(String password) async {
    return await _prefs.setString(AppConstants.keyRememberedPassword, password);
  }

  Future<bool> removeRememberedPassword() async {
    return await _prefs.remove(AppConstants.keyRememberedPassword);
  }

  // --- Session Management ---
  bool isGuestSession() {
    return _prefs.getBool(AppConstants.keyGuestSession) ?? false;
  }

  Future<bool> setGuestSession(bool isGuest) async {
    return await _prefs.setBool(AppConstants.keyGuestSession, isGuest);
  }

  UserModel? getUserSession() {
    final userJson = _prefs.getString(AppConstants.keyUserSession);
    if (userJson == null) return null;
    try {
      final Map<String, dynamic> userMap = json.decode(userJson);
      return UserModel.fromJson(userMap);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setUserSession(UserModel user) async {
    final userJson = json.encode(user.toJson());
    return await _prefs.setString(AppConstants.keyUserSession, userJson);
  }

  Future<bool> clearUserSession() async {
    return await _prefs.remove(AppConstants.keyUserSession);
  }

  Future<void> clearAll() async {
    final theme = getThemeMode();
    final firstLaunch = isFirstLaunch();
    await _prefs.clear();
    // Maintain settings
    await setThemeMode(theme);
    if (!firstLaunch) {
      await setFirstLaunchCompleted();
    }
  }
}
