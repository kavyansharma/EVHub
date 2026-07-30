import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import 'payment_gateway_abstraction.dart';

/// Result object for wallet operations.
class WalletTransactionResult {
  final bool isSuccess;
  final WalletModel wallet;
  final WalletTransactionModel? transaction;
  final String? errorMessage;
  final WalletTransactionModel? autoTopUpTransaction;

  const WalletTransactionResult({
    required this.isSuccess,
    required this.wallet,
    this.transaction,
    this.errorMessage,
    this.autoTopUpTransaction,
  });

  factory WalletTransactionResult.success(
    WalletModel wallet,
    WalletTransactionModel transaction, {
    WalletTransactionModel? autoTopUpTx,
  }) {
    return WalletTransactionResult(
      isSuccess: true,
      wallet: wallet,
      transaction: transaction,
      autoTopUpTransaction: autoTopUpTx,
    );
  }

  factory WalletTransactionResult.failure(WalletModel wallet, String message) {
    return WalletTransactionResult(
      isSuccess: false,
      wallet: wallet,
      errorMessage: message,
    );
  }
}

/// Core single source of truth for Universal Wallet state, ledger, persistence,
/// and mock payment operations.
class WalletService {
  static const String _prefsWalletKey = 'chargeone_wallet_data';
  static const String _prefsTxKey = 'chargeone_wallet_transactions';

  final PaymentGateway _paymentGateway;
  WalletModel? _cachedWallet;
  List<WalletTransactionModel> _cachedTransactions = [];
  bool _isInitialized = false;
  bool _isMutating = false;
  final Random _random = Random();

  WalletService({PaymentGateway? paymentGateway})
      : _paymentGateway = paymentGateway ?? MockPaymentGateway();

  /// Ensures wallet state is loaded from local persistence.
  Future<void> initialize({String userId = 'local_user'}) async {
    if (_isInitialized && _cachedWallet != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final walletJsonStr = prefs.getString(_prefsWalletKey);

      if (walletJsonStr != null && walletJsonStr.isNotEmpty) {
        final map = jsonDecode(walletJsonStr) as Map<String, dynamic>;
        _cachedWallet = WalletModel.fromJson(map);
      } else {
        _cachedWallet = WalletModel.initial(userId);
        await _persistWallet(_cachedWallet!);
      }

      final txJsonStr = prefs.getString(_prefsTxKey);
      if (txJsonStr != null && txJsonStr.isNotEmpty) {
        final List list = jsonDecode(txJsonStr);
        _cachedTransactions = list
            .map((item) => WalletTransactionModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _cachedTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _cachedTransactions = [];
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[WalletService] Initialization fallback: $e');
      _cachedWallet ??= WalletModel.initial(userId);
      _cachedTransactions = [];
      _isInitialized = true;
    }
  }

  /// Get current wallet instance.
  Future<WalletModel> getWallet({String userId = 'local_user'}) async {
    await initialize(userId: userId);
    return _cachedWallet!;
  }

  /// Get current balance in INR.
  Future<double> getBalance({String userId = 'local_user'}) async {
    final w = await getWallet(userId: userId);
    return w.balance;
  }

  /// Get transaction history (newest first).
  Future<List<WalletTransactionModel>> getTransactions({String userId = 'local_user'}) async {
    await initialize(userId: userId);
    return List.unmodifiable(_cachedTransactions);
  }

  /// Get single transaction by ID.
  Future<WalletTransactionModel?> getTransactionById(String txId) async {
    await initialize();
    try {
      return _cachedTransactions.firstWhere((t) => t.transactionId == txId || t.referenceId == txId);
    } catch (_) {
      return null;
    }
  }

  /// Check if wallet has sufficient balance for amount.
  bool hasSufficientBalance(double requiredAmount) {
    if (_cachedWallet == null) return false;
    return _cachedWallet!.balance >= requiredAmount;
  }

  /// Add Money / Top-Up mock transaction.
  Future<WalletTransactionResult> addMoney({
    required double amount,
    String paymentMethod = 'Mock Payment Gateway',
    MockPaymentOutcome simulatedOutcome = MockPaymentOutcome.success,
    String userId = 'local_user',
  }) async {
    await initialize(userId: userId);

    if (_isMutating) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Transaction already in progress.');
    }

    // Validation rules
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Invalid top-up amount.');
    }
    if (amount < 10.0) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Minimum top-up amount is ₹10.');
    }
    if (amount > 10000.0) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Maximum mock top-up limit is ₹10,000.');
    }

    _isMutating = true;
    try {
      final gatewayResult = await _paymentGateway.processPayment(
        amount: amount,
        currency: _cachedWallet!.currency,
        paymentMethod: paymentMethod,
        simulatedOutcome: simulatedOutcome,
      );

      final now = DateTime.now();

      if (!gatewayResult.isSuccess) {
        final failedTx = WalletTransactionModel(
          transactionId: _generateTxId(),
          walletId: _cachedWallet!.walletId,
          userId: _cachedWallet!.userId,
          type: WalletTransactionType.topUp,
          status: simulatedOutcome == MockPaymentOutcome.cancelled
              ? WalletTransactionStatus.reversed
              : WalletTransactionStatus.failed,
          amount: amount,
          currency: _cachedWallet!.currency,
          description: simulatedOutcome == MockPaymentOutcome.cancelled
              ? 'Wallet Top-Up Cancelled'
              : 'Wallet Top-Up Failed',
          referenceId: gatewayResult.referenceId,
          createdAt: now,
        );

        _cachedTransactions.insert(0, failedTx);
        await _persistTransactions();
        _isMutating = false;

        return WalletTransactionResult.failure(
          _cachedWallet!,
          gatewayResult.errorMessage ?? 'Payment failed.',
        );
      }

      // Successful top-up
      final newBalance = _cachedWallet!.balance + amount;
      _cachedWallet = _cachedWallet!.copyWith(balance: newBalance, lastUpdated: now);

      final successTx = WalletTransactionModel(
        transactionId: _generateTxId(),
        walletId: _cachedWallet!.walletId,
        userId: _cachedWallet!.userId,
        type: WalletTransactionType.topUp,
        status: WalletTransactionStatus.success,
        amount: amount,
        currency: _cachedWallet!.currency,
        description: 'Wallet Top-Up via $paymentMethod',
        referenceId: gatewayResult.referenceId,
        createdAt: now,
      );

      _cachedTransactions.insert(0, successTx);
      await _persistWallet(_cachedWallet!);
      await _persistTransactions();
      _isMutating = false;

      return WalletTransactionResult.success(_cachedWallet!, successTx);
    } catch (e) {
      _isMutating = false;
      return WalletTransactionResult.failure(_cachedWallet!, 'Top-up error: $e');
    }
  }

  /// Debit wallet (e.g. for charging session).
  Future<WalletTransactionResult> debit({
    required double amount,
    required String description,
    String? networkName,
    String? chargerId,
    String? chargerName,
    String? chargingSessionId,
    String userId = 'local_user',
  }) async {
    await initialize(userId: userId);

    if (_isMutating) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Transaction already in progress.');
    }

    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Invalid debit amount.');
    }

    if (_cachedWallet!.balance < amount) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Insufficient wallet balance');
    }

    _isMutating = true;
    try {
      final now = DateTime.now();
      final newBalance = _cachedWallet!.balance - amount;
      _cachedWallet = _cachedWallet!.copyWith(balance: newBalance, lastUpdated: now);

      final refId = _generateRefId('MOCK-CHG');
      final debitTx = WalletTransactionModel(
        transactionId: _generateTxId(),
        walletId: _cachedWallet!.walletId,
        userId: _cachedWallet!.userId,
        type: WalletTransactionType.chargingPayment,
        status: WalletTransactionStatus.success,
        amount: amount,
        currency: _cachedWallet!.currency,
        description: description,
        networkName: networkName,
        chargerId: chargerId,
        chargerName: chargerName,
        chargingSessionId: chargingSessionId,
        referenceId: refId,
        createdAt: now,
      );

      _cachedTransactions.insert(0, debitTx);

      // Check simulated Auto Top-Up trigger
      WalletTransactionModel? autoTopUpTx;
      if (_cachedWallet!.autoTopUpEnabled && _cachedWallet!.balance < _cachedWallet!.autoTopUpThreshold) {
        final autoAmount = _cachedWallet!.autoTopUpAmount;
        final autoBalance = _cachedWallet!.balance + autoAmount;
        _cachedWallet = _cachedWallet!.copyWith(balance: autoBalance, lastUpdated: DateTime.now());

        autoTopUpTx = WalletTransactionModel(
          transactionId: _generateTxId(),
          walletId: _cachedWallet!.walletId,
          userId: _cachedWallet!.userId,
          type: WalletTransactionType.topUp,
          status: WalletTransactionStatus.success,
          amount: autoAmount,
          currency: _cachedWallet!.currency,
          description: 'Mock Auto Top-Up (Threshold < ₹${_cachedWallet!.autoTopUpThreshold.toStringAsFixed(0)})',
          referenceId: _generateRefId('MOCK-AUTO'),
          createdAt: DateTime.now(),
        );

        _cachedTransactions.insert(0, autoTopUpTx);
      }

      await _persistWallet(_cachedWallet!);
      await _persistTransactions();
      _isMutating = false;

      return WalletTransactionResult.success(
        _cachedWallet!,
        debitTx,
        autoTopUpTx: autoTopUpTx,
      );
    } catch (e) {
      _isMutating = false;
      return WalletTransactionResult.failure(_cachedWallet!, 'Debit error: $e');
    }
  }

  /// Credit wallet (Refund or Cashback).
  Future<WalletTransactionResult> credit({
    required double amount,
    required String description,
    WalletTransactionType type = WalletTransactionType.refund,
    String? referenceId,
    String userId = 'local_user',
  }) async {
    await initialize(userId: userId);

    if (_isMutating) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Transaction in progress.');
    }

    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      return WalletTransactionResult.failure(_cachedWallet!, 'Invalid credit amount.');
    }

    _isMutating = true;
    try {
      final now = DateTime.now();
      final newBalance = _cachedWallet!.balance + amount;
      _cachedWallet = _cachedWallet!.copyWith(balance: newBalance, lastUpdated: now);

      final creditTx = WalletTransactionModel(
        transactionId: _generateTxId(),
        walletId: _cachedWallet!.walletId,
        userId: _cachedWallet!.userId,
        type: type,
        status: WalletTransactionStatus.success,
        amount: amount,
        currency: _cachedWallet!.currency,
        description: description,
        referenceId: referenceId ?? _generateRefId('MOCK-CRED'),
        createdAt: now,
      );

      _cachedTransactions.insert(0, creditTx);
      await _persistWallet(_cachedWallet!);
      await _persistTransactions();
      _isMutating = false;

      return WalletTransactionResult.success(_cachedWallet!, creditTx);
    } catch (e) {
      _isMutating = false;
      return WalletTransactionResult.failure(_cachedWallet!, 'Credit error: $e');
    }
  }

  /// Helper refund action.
  Future<WalletTransactionResult> refund({
    required double amount,
    required String originalReferenceId,
    String? description,
  }) async {
    return credit(
      amount: amount,
      description: description ?? 'Refund for transaction $originalReferenceId',
      type: WalletTransactionType.refund,
      referenceId: 'MOCK-REFUND-$originalReferenceId',
    );
  }

  /// Helper cashback action.
  Future<WalletTransactionResult> addCashback({
    required double amount,
    String? description,
  }) async {
    return credit(
      amount: amount,
      description: description ?? 'Cashback Reward Credit',
      type: WalletTransactionType.cashback,
      referenceId: _generateRefId('MOCK-CB'),
    );
  }

  /// Update Auto Top-Up configuration.
  Future<bool> updateAutoTopUpSettings({
    required bool enabled,
    double? threshold,
    double? amount,
    String userId = 'local_user',
  }) async {
    await initialize(userId: userId);
    _cachedWallet = _cachedWallet!.copyWith(
      autoTopUpEnabled: enabled,
      autoTopUpThreshold: threshold ?? _cachedWallet!.autoTopUpThreshold,
      autoTopUpAmount: amount ?? _cachedWallet!.autoTopUpAmount,
    );
    await _persistWallet(_cachedWallet!);
    return true;
  }

  /// Reset wallet to ₹0 demo state.
  Future<void> resetDemoWallet({String userId = 'local_user'}) async {
    await initialize(userId: userId);
    _cachedWallet = WalletModel.initial(userId);
    _cachedTransactions.clear();
    await _persistWallet(_cachedWallet!);
    await _persistTransactions();
  }

  /// Clear persisted wallet data.
  Future<void> clearWallet() async {
    _cachedWallet = WalletModel.initial('local_user');
    _cachedTransactions.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsWalletKey);
      await prefs.remove(_prefsTxKey);
    } catch (_) {}
  }

  Future<void> _persistWallet(WalletModel wallet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsWalletKey, jsonEncode(wallet.toJson()));
    } catch (e) {
      debugPrint('[WalletService] Persist wallet error: $e');
    }
  }

  Future<void> _persistTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cachedTransactions.map((t) => t.toJson()).toList();
      await prefs.setString(_prefsTxKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[WalletService] Persist transactions error: $e');
    }
  }

  String _generateTxId() {
    return 'tx_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1000)}';
  }

  String _generateRefId(String prefix) {
    final dateStr = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 8);
    final randNum = _random.nextInt(900000) + 100000;
    return '$prefix-$dateStr-$randNum';
  }
}
