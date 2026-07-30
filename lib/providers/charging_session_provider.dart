import 'dart:async';
import 'package:flutter/material.dart';

import '../models/charging_session_model.dart';
import '../repositories/charging_session_repository.dart';
import '../services/charging_session_service.dart';
import 'wallet_provider.dart';

/// Central reactive state provider managing simulated EV charging sessions,
/// session persistence, power curve visualization, and wallet payment settlement.
class ChargingSessionProvider extends ChangeNotifier {
  final ChargingSessionService _service;
  final ChargingSessionRepository? _repository;

  ChargingSessionModel? _activeSession;
  List<ChargingSessionModel> _sessionHistory = [];
  StreamSubscription<ChargingSessionModel>? _serviceStreamSub;

  bool _isLoading = false;
  bool _isProcessingPayment = false;
  String? _errorMessage;
  String? _paymentError;

  ChargingSessionProvider({
    ChargingSessionService? service,
    ChargingSessionRepository? repository,
  })  : _service = service ?? ChargingSessionService(),
        _repository = repository {
    loadSessionState();
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  ChargingSessionModel? get activeSession => _activeSession;
  List<ChargingSessionModel> get sessionHistory => List.unmodifiable(_sessionHistory);
  bool get isLoading => _isLoading;
  bool get isProcessingPayment => _isProcessingPayment;
  String? get errorMessage => _errorMessage;
  String? get paymentError => _paymentError;

  bool get isCharging => _activeSession?.status == ChargingSessionStatus.charging;
  bool get isPaused => _activeSession?.status == ChargingSessionStatus.paused;
  bool get isCompleting => _activeSession?.status == ChargingSessionStatus.completing;
  bool get isPaymentPending => _activeSession?.status == ChargingSessionStatus.paymentPending;
  bool get isCompleted => _activeSession?.status == ChargingSessionStatus.completed;

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Initialize provider and listen to service stream updates.
  Future<void> loadSessionState() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.initialize();
      _activeSession = await _service.getActiveSession();
      _sessionHistory = await _service.getSessionHistory();

      _serviceStreamSub?.cancel();
      _serviceStreamSub = _service.sessionStream.listen((updatedSession) {
        _activeSession = updatedSession;
        if (_repository != null && _activeSession != null) {
          _repository.updateSessionState(_activeSession!);
        }
        notifyListeners();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start a new simulated EV charging session with flexible parameters.
  Future<ChargingSessionModel?> startSession({
    required String userId,
    required String chargerId,
    String chargerName = 'EV Charging Station',
    String networkName = 'EVHub Network',
    String chargerAddress = 'India EV Charger Station',
    String vehicleId = 'ev_default',
    String vehicleName = 'Electric Vehicle',
    String connectorType = 'CCS2',
    double chargerPowerKw = 60.0,
    double vehicleMaxPowerKw = 120.0,
    double initialSocPercent = 20.0,
    double targetSocPercent = 80.0,
    double batteryCapacityKwh = 50.0,
    double pricePerKwh = 18.0,
    double chargingEfficiency = 0.90,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _paymentError = null;
    notifyListeners();

    try {
      final session = await _service.startSession(
        userId: userId,
        chargerId: chargerId,
        chargerName: chargerName,
        networkName: networkName,
        chargerAddress: chargerAddress,
        vehicleId: vehicleId,
        vehicleName: vehicleName,
        connectorType: connectorType,
        chargerPowerKw: chargerPowerKw,
        vehicleMaxPowerKw: vehicleMaxPowerKw,
        initialSocPercent: initialSocPercent,
        targetSocPercent: targetSocPercent,
        batteryCapacityKwh: batteryCapacityKwh,
        pricePerKwh: pricePerKwh,
        chargingEfficiency: chargingEfficiency,
      );

      _activeSession = session;
      if (_repository != null) {
        await _repository.saveSession(session);
      }

      _isLoading = false;
      notifyListeners();
      return session;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Pause charging.
  Future<void> pauseSession() async {
    try {
      _activeSession = await _service.pauseSession();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Resume charging.
  Future<void> resumeSession() async {
    try {
      _activeSession = await _service.resumeSession();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Stop charging session and transition to payment pending.
  Future<void> stopSession() async {
    try {
      _activeSession = await _service.stopSession();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Cancel active session.
  Future<void> cancelSession() async {
    try {
      await _service.cancelSession();
      _activeSession = null;
      _sessionHistory = await _service.getSessionHistory();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Process final wallet payment for the session.
  Future<bool> processSessionPayment({
    required WalletProvider walletProvider,
    String userId = 'local_user',
  }) async {
    if (_activeSession == null) {
      _paymentError = 'No active session found for payment.';
      notifyListeners();
      return false;
    }

    // Prevent duplicate payment
    if (_activeSession!.status == ChargingSessionStatus.completed) {
      return true;
    }

    _isProcessingPayment = true;
    _paymentError = null;
    notifyListeners();

    final session = _activeSession!;
    final finalCost = session.finalCost > 0 ? session.finalCost : session.estimatedCost;

    // 1. Check wallet balance
    if (walletProvider.balance < finalCost) {
      await _service.markPaymentFailed('Insufficient wallet balance');
      _paymentError = 'Insufficient wallet balance. Please add funds to complete payment.';
      _isProcessingPayment = false;
      notifyListeners();
      return false;
    }

    // 2. Perform wallet debit
    final debitSuccess = await walletProvider.debit(
      amount: finalCost,
      description: 'Charging Session — ${session.chargerName} (${session.energyDeliveredKwh.toStringAsFixed(1)} kWh)',
      networkName: session.networkName,
      chargerId: session.chargerId,
      chargerName: session.chargerName,
      chargingSessionId: session.sessionId,
      userId: userId,
    );

    if (!debitSuccess) {
      await _service.markPaymentFailed(walletProvider.errorMessage ?? 'Payment processing failed');
      _paymentError = walletProvider.errorMessage ?? 'Wallet payment failed.';
      _isProcessingPayment = false;
      notifyListeners();
      return false;
    }

    // 3. Mark session as completed
    final lastTx = walletProvider.transactions.first;
    await _service.markPaymentSuccessful(
      transactionId: lastTx.transactionId,
      referenceId: lastTx.referenceId,
    );

    _sessionHistory = await _service.getSessionHistory();
    _isProcessingPayment = false;
    notifyListeners();
    return true;
  }

  /// Clear active session state.
  Future<void> clearCompletedSession() async {
    await _service.clearActiveSession();
    _activeSession = null;
    notifyListeners();
  }

  void clearErrors() {
    _errorMessage = null;
    _paymentError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _serviceStreamSub?.cancel();
    super.dispose();
  }
}
