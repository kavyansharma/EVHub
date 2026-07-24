import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'user_repository.dart';

abstract class AuthRepository {
  Future<UserModel> login({
    required String email,
    required String password,
    bool rememberMe = false,
  });
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
  });
  Future<void> forgotPassword(String email);
  Future<UserModel?> restoreSession();
  Future<void> logout();
  Future<UserModel> startGuestSession();
  Future<UserModel?> googleSignIn();

  // Remember Me helpers
  bool isRememberMeEnabled();
  Map<String, String>? getRememberedCredentials();
  Future<void> clearRememberedCredentials();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final StorageService _storageService;
  final UserRepository _userRepository;

  AuthRepositoryImpl({
    required AuthService authService,
    required StorageService storageService,
    required UserRepository userRepository,
  })  : _authService = authService,
        _storageService = storageService,
        _userRepository = userRepository;

  // ─── Login ─────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final credential = await _authService.signInWithEmailAndPassword(
      email,
      password,
    );
    final fbUser = credential.user!;
    debugPrint('[AuthRepository] Auth successful for uid="${fbUser.uid}", email="${fbUser.email}"');

    UserModel? user = await _userRepository.getUserDocument(fbUser.uid);

    if (user != null) {
      debugPrint('[AuthRepository] Firestore user profile loaded: uid="${user.id}", role="${user.role.name}", isAdmin=${user.isAdmin}');
    } else {
      debugPrint('[AuthRepository] ⚠ No Firestore user profile found for uid="${fbUser.uid}". Creating default user profile...');
      user = UserModel(
        id: fbUser.uid,
        email: fbUser.email ?? email,
        name: fbUser.displayName ?? 'EV Driver',
        avatarUrl: fbUser.photoURL,
        isGuest: false,
      );
      await _userRepository.createUserDocument(user);
    }

    // Remember Me — store email only.
    await _storageService.setRememberMe(rememberMe);
    if (rememberMe) {
      await _storageService.setRememberedEmail(email);
    } else {
      await _storageService.removeRememberedEmail();
    }

    return user;
  }

  // ─── Signup ────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _authService.createUserWithEmailAndPassword(
      email,
      password,
      name,
    );
    final fbUser = credential.user!;
    final user = UserModel(
      id: fbUser.uid,
      email: fbUser.email ?? email,
      name: name.trim(),
      avatarUrl: fbUser.photoURL,
      isGuest: false,
    );

    // Create Firestore user document + wallet.
    await _userRepository.createUserDocument(user);
    return user;
  }

  // ─── Forgot Password ───────────────────────────────────────────────────────

  @override
  Future<void> forgotPassword(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  // ─── Restore Session ───────────────────────────────────────────────────────

  @override
  Future<UserModel?> restoreSession() async {
    final fbUser = _authService.currentUser;
    if (fbUser == null) {
      debugPrint('[AuthRepository] restoreSession: No active Firebase Auth user.');
      return null;
    }

    debugPrint('[AuthRepository] restoreSession: Found Firebase Auth user uid="${fbUser.uid}", isAnonymous=${fbUser.isAnonymous}');

    if (fbUser.isAnonymous) {
      return UserModel.guest();
    }

    // Try to fetch profile from Firestore.
    final saved = await _userRepository.getUserDocument(fbUser.uid);
    if (saved != null) {
      debugPrint('[AuthRepository] restoreSession: Loaded profile for uid="${saved.id}", role="${saved.role.name}", isAdmin=${saved.isAdmin}');
      return saved;
    }

    debugPrint('[AuthRepository] ⚠ restoreSession: Firestore doc missing for uid="${fbUser.uid}". Using default fallback user model.');
    return UserModel(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      name: fbUser.displayName ?? 'EV Driver',
      avatarUrl: fbUser.photoURL,
      isGuest: false,
    );
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    await _authService.signOut();
    await _storageService.setRememberMe(false);
    await _storageService.removeRememberedEmail();
  }

  // ─── Guest / Anonymous ─────────────────────────────────────────────────────

  @override
  Future<UserModel> startGuestSession() async {
    await _authService.signInAnonymously();
    return UserModel.guest();
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  @override
  Future<UserModel?> googleSignIn() async {
    final credential = await _authService.signInWithGoogle();
    if (credential == null) return null;

    final fbUser = credential.user!;
    final user = UserModel(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      name: fbUser.displayName ?? 'EV Driver',
      avatarUrl: fbUser.photoURL,
      isGuest: false,
    );

    await _userRepository.createUserDocument(user);
    return user;
  }

  // ─── Remember Me ───────────────────────────────────────────────────────────

  @override
  bool isRememberMeEnabled() => _storageService.getRememberMe();

  @override
  Map<String, String>? getRememberedCredentials() {
    if (!isRememberMeEnabled()) return null;
    final email = _storageService.getRememberedEmail();
    if (email != null) {
      return {'email': email};
    }
    return null;
  }

  @override
  Future<void> clearRememberedCredentials() async {
    await _storageService.setRememberMe(false);
    await _storageService.removeRememberedEmail();
  }
}
