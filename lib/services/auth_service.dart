import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final SharedPreferences _prefs;
  static const String _keyUsersList = 'registered_users_list';

  AuthService(this._prefs);

  static Future<AuthService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthService(prefs);
  }

  // Helper validation methods
  static bool validateEmail(String email) {
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email.trim());
  }

  static bool validatePassword(String password) {
    // Password must be at least 6 characters
    return password.trim().length >= 6;
  }

  // Retrieve all simulated users from local database
  Map<String, Map<String, dynamic>> _getUsersDatabase() {
    final rawJson = _prefs.getString(_keyUsersList);
    if (rawJson == null) {
      // Default mock users
      return {
        'admin@evhub.com': {
          'id': 'user_admin',
          'email': 'admin@evhub.com',
          'password': 'password123',
          'name': 'Tesla Driver',
          'walletBalance': 150.00,
        },
        'demo@evhub.com': {
          'id': 'user_demo',
          'email': 'demo@evhub.com',
          'password': 'password123',
          'name': 'EV Enthusiast',
          'walletBalance': 50.00,
        }
      };
    }
    try {
      final Map<String, dynamic> decoded = json.decode(rawJson);
      return decoded.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
    } catch (_) {
      return {};
    }
  }

  // Save changes to local database
  Future<void> _saveUsersDatabase(Map<String, Map<String, dynamic>> db) async {
    await _prefs.setString(_keyUsersList, json.encode(db));
  }

  // Simulate authentication login
  Future<UserModel> login({required String email, required String password}) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network latency

    final db = _getUsersDatabase();
    final normalizedEmail = email.trim().toLowerCase();

    if (!db.containsKey(normalizedEmail)) {
      throw Exception('User account not found. Please sign up.');
    }

    final userRecord = db[normalizedEmail]!;
    if (userRecord['password'] != password) {
      throw Exception('Incorrect password. Please try again.');
    }

    return UserModel(
      id: userRecord['id'],
      email: userRecord['email'],
      name: userRecord['name'],
      walletBalance: (userRecord['walletBalance'] ?? 0.0) as double,
      isGuest: false,
    );
  }

  // Simulate registration signup
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network latency

    final db = _getUsersDatabase();
    final normalizedEmail = email.trim().toLowerCase();

    if (db.containsKey(normalizedEmail)) {
      throw Exception('An account with this email already exists.');
    }

    final newId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    db[normalizedEmail] = {
      'id': newId,
      'email': normalizedEmail,
      'password': password,
      'name': name.trim(),
      'walletBalance': 100.0, // Default welcome balance
    };

    await _saveUsersDatabase(db);

    return UserModel(
      id: newId,
      email: normalizedEmail,
      name: name.trim(),
      walletBalance: 100.0,
      isGuest: false,
    );
  }

  // Simulate Password Reset request
  Future<void> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Latency simulation
    final db = _getUsersDatabase();
    final normalizedEmail = email.trim().toLowerCase();

    if (!db.containsKey(normalizedEmail)) {
      throw Exception('No account found with this email.');
    }
    // Simulation: in production this triggers emails
  }
}
