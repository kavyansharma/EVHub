import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final StorageService _storageService;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFirstLaunch = true;
  bool _rememberMe = false;

  AuthProvider({
    required AuthRepository authRepository,
    required StorageService storageService,
  })  : _authRepository = authRepository,
        _storageService = storageService {
    _isFirstLaunch = _storageService.isFirstLaunch();
    _rememberMe = _storageService.getRememberMe();
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get rememberMe => _rememberMe;
  bool get isAuthenticated => _user != null;

  void toggleRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _storageService.setFirstLaunchCompleted();
    _isFirstLaunch = false;
    notifyListeners();
  }

  Future<bool> restoreSession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final restoredUser = await _authRepository.restoreSession();
      if (restoredUser != null) {
        _user = restoredUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.login(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.signup(
        email: email,
        password: password,
        name: name,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.forgotPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loginAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _user = await _authRepository.startGuestSession();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authRepository.logout();
    _user = null;

    _isLoading = false;
    notifyListeners();
  }

  Map<String, String>? getRememberedCredentials() {
    return _authRepository.getRememberedCredentials();
  }
}
