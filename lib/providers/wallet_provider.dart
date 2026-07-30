import 'dart:async';
import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../repositories/wallet_repository.dart';
import '../services/payment_gateway_abstraction.dart';
import '../services/wallet_service.dart';

/// Central provider managing Universal Wallet balance, transaction ledger,
/// auto top-up settings, and mock payment gateway operations.
class WalletProvider extends ChangeNotifier {
  final WalletService _walletService;
  // Retained for Firestore stream backward compatibility if needed
  final WalletRepository? _walletRepository;

  WalletModel? _wallet;
  List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isProcessingPayment = false;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<WalletModel?>? _walletSub;
  StreamSubscription<List<TransactionModel>>? _txSub;

  WalletProvider({
    WalletService? walletService,
    WalletRepository? walletRepository,
  })  : _walletService = walletService ?? WalletService(),
        _walletRepository = walletRepository {
    loadWallet();
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  WalletModel? get wallet => _wallet;
  double get balance => _wallet?.balance ?? 0.0;
  String get currency => _wallet?.currency ?? 'INR';
  List<WalletTransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  bool get isProcessingPayment => _isProcessingPayment;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Legacy accessor for old code relying on TransactionModel list
  List<TransactionModel> get legacyTransactions =>
      _transactions.map((wt) => TransactionModel.fromWalletTransaction(wt)).toList();

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Initialize and load wallet from storage.
  Future<void> loadWallet({String userId = 'local_user'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _wallet = await _walletService.getWallet(userId: userId);
      _transactions = await _walletService.getTransactions(userId: userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Perform mock Add Money / Top-Up.
  Future<bool> addMoney({
    required double amount,
    String paymentMethod = 'Mock Payment',
    MockPaymentOutcome simulatedOutcome = MockPaymentOutcome.success,
    String userId = 'local_user',
  }) async {
    _isProcessingPayment = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _walletService.addMoney(
        amount: amount,
        paymentMethod: paymentMethod,
        simulatedOutcome: simulatedOutcome,
        userId: userId,
      );

      _wallet = result.wallet;
      _transactions = await _walletService.getTransactions(userId: userId);
      _isProcessingPayment = false;

      if (result.isSuccess) {
        _successMessage = '₹${amount.toStringAsFixed(0)} added to your ChargeOne Wallet!';
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Top-up failed.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isProcessingPayment = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Debit wallet for charging or purchase.
  Future<bool> debit({
    required double amount,
    required String description,
    String? networkName,
    String? chargerId,
    String? chargerName,
    String? chargingSessionId,
    String userId = 'local_user',
  }) async {
    _isProcessingPayment = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _walletService.debit(
        amount: amount,
        description: description,
        networkName: networkName,
        chargerId: chargerId,
        chargerName: chargerName,
        chargingSessionId: chargingSessionId,
        userId: userId,
      );

      _wallet = result.wallet;
      _transactions = await _walletService.getTransactions(userId: userId);
      _isProcessingPayment = false;

      if (result.isSuccess) {
        _successMessage = '₹${amount.toStringAsFixed(2)} debited successfully.';
        if (result.autoTopUpTransaction != null) {
          _successMessage = 'Debited ₹${amount.toStringAsFixed(2)}. Mock Auto Top-Up triggered (+₹${result.autoTopUpTransaction!.amount.toStringAsFixed(0)}).';
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Debit failed.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isProcessingPayment = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Credit wallet (refund / cashback / adjustment).
  Future<bool> credit({
    required double amount,
    required String description,
    WalletTransactionType type = WalletTransactionType.refund,
    String? referenceId,
    String userId = 'local_user',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _walletService.credit(
        amount: amount,
        description: description,
        type: type,
        referenceId: referenceId,
        userId: userId,
      );

      _wallet = result.wallet;
      _transactions = await _walletService.getTransactions(userId: userId);
      _isLoading = false;

      if (result.isSuccess) {
        _successMessage = '₹${amount.toStringAsFixed(2)} credited to your wallet.';
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Credit failed.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Refund helper.
  Future<bool> refund({
    required double amount,
    required String originalReferenceId,
    String? description,
  }) async {
    return credit(
      amount: amount,
      description: description ?? 'Refund for $originalReferenceId',
      type: WalletTransactionType.refund,
      referenceId: 'MOCK-REFUND-$originalReferenceId',
    );
  }

  /// Update Auto Top-Up settings.
  Future<bool> updateAutoTopUpSettings({
    required bool enabled,
    double? threshold,
    double? amount,
  }) async {
    _isLoading = true;
    notifyListeners();

    await _walletService.updateAutoTopUpSettings(
      enabled: enabled,
      threshold: threshold,
      amount: amount,
    );

    _wallet = await _walletService.getWallet();
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> refreshTransactions() async {
    _transactions = await _walletService.getTransactions();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  // ─── Backward Compatibility Layer ───────────────────────────────────────

  /// Legacy method for Firestore streaming support.
  void loadForUser(String uid) {
    if (_walletRepository != null) {
      _cancelSubscriptions();
      _isLoading = true;
      notifyListeners();

      _walletSub = _walletRepository.watchWallet(uid).listen((w) {
        if (w != null) _wallet = w;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      });
    } else {
      loadWallet(userId: uid);
    }
  }

  /// Legacy method for topUp.
  Future<bool> topUp(String uid, double amount) async {
    return addMoney(amount: amount, userId: uid);
  }

  /// Legacy method for deduct.
  Future<bool> deduct(String uid, double amount, String description) async {
    return debit(amount: amount, description: description, userId: uid);
  }

  void clear() {
    _cancelSubscriptions();
    _wallet = null;
    _transactions = [];
    _isLoading = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _walletSub?.cancel();
    _txSub?.cancel();
    _walletSub = null;
    _txSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
