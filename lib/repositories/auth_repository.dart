import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password, bool rememberMe = false});
  Future<UserModel> signup({required String email, required String password, required String name});
  Future<void> forgotPassword(String email);
  Future<UserModel?> restoreSession();
  Future<void> logout();
  Future<UserModel> startGuestSession();

  // Remember Me helpers
  bool isRememberMeEnabled();
  Map<String, String>? getRememberedCredentials();
  Future<void> clearRememberedCredentials();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final StorageService _storageService;

  AuthRepositoryImpl({
    required AuthService authService,
    required StorageService storageService,
  })  : _authService = authService,
        _storageService = storageService;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final user = await _authService.login(email: email, password: password);
      
      // Store session
      await _storageService.setUserSession(user);
      await _storageService.setGuestSession(false);
      await _storageService.setRememberMe(rememberMe);

      if (rememberMe) {
        await _storageService.setRememberedEmail(email);
        await _storageService.setRememberedPassword(password);
      } else {
        await _storageService.removeRememberedEmail();
        await _storageService.removeRememberedPassword();
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final user = await _authService.signup(email: email, password: password, name: name);
      // Automatically log them in on sign up
      await _storageService.setUserSession(user);
      await _storageService.setGuestSession(false);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _authService.requestPasswordReset(email);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel?> restoreSession() async {
    // 1. Check if guest session was active
    if (_storageService.isGuestSession()) {
      return UserModel.guest();
    }

    // 2. Check if user session exists
    final savedUser = _storageService.getUserSession();
    if (savedUser != null) {
      return savedUser;
    }

    return null;
  }

  @override
  Future<void> logout() async {
    await _storageService.clearUserSession();
    await _storageService.setGuestSession(false);
  }

  @override
  Future<UserModel> startGuestSession() async {
    final guest = UserModel.guest();
    await _storageService.setGuestSession(true);
    await _storageService.clearUserSession();
    return guest;
  }

  @override
  bool isRememberMeEnabled() {
    return _storageService.getRememberMe();
  }

  @override
  Map<String, String>? getRememberedCredentials() {
    if (!isRememberMeEnabled()) return null;
    final email = _storageService.getRememberedEmail();
    final pwd = _storageService.getRememberedPassword();
    if (email != null && pwd != null) {
      return {'email': email, 'password': pwd};
    }
    return null;
  }

  @override
  Future<void> clearRememberedCredentials() async {
    await _storageService.setRememberMe(false);
    await _storageService.removeRememberedEmail();
    await _storageService.removeRememberedPassword();
  }
}
