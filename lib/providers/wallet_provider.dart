import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../repositories/wallet_repository.dart';

/// Provides real-time wallet balance and transaction list from Firestore.
/// Must be initialized with [loadForUser] after login.
class WalletProvider extends ChangeNotifier {
  final WalletRepository _walletRepository;

  WalletModel? _wallet;
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<WalletModel?>? _walletSub;
  StreamSubscription<List<TransactionModel>>? _txSub;

  WalletProvider({required WalletRepository walletRepository})
      : _walletRepository = walletRepository;

  // ─── Getters ───────────────────────────────────────────────────────────────

  double get balance => _wallet?.balance ?? 0.0;
  String get currency => _wallet?.currency ?? 'INR';
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start streaming wallet data for the given user.
  void loadForUser(String uid) {
    _cancelSubscriptions();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _walletSub = _walletRepository.watchWallet(uid).listen(
      (wallet) {
        _wallet = wallet;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    _txSub = _walletRepository.watchTransactions(uid).listen(
      (txList) {
        _transactions = txList;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  /// Clear data when user logs out.
  void clear() {
    _cancelSubscriptions();
    _wallet = null;
    _transactions = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _walletSub = null;
    _txSub = null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Top up wallet by [amount] USD.
  Future<bool> topUp(String uid, double amount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _walletRepository.topUp(
        uid,
        amount,
        'Wallet Top-up',
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

  /// Deduct [amount] USD (e.g., for a charging session).
  Future<bool> deduct(String uid, double amount, String description) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _walletRepository.deduct(uid, amount, description);
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

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
