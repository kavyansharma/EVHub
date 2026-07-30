import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/charging_session_model.dart';

/// Single source of truth for realistic simulated EV charging session lifecycle,
/// power tapering math, local storage persistence, and session state transitions.
class ChargingSessionService {
  static const String _prefsActiveSessionKey = 'chargeone_active_charging_session';
  static const String _prefsHistoryKey = 'chargeone_charging_session_history';

  Timer? _simulationTimer;
  ChargingSessionModel? _activeSession;
  List<ChargingSessionModel> _sessionHistory = [];
  bool _isInitialized = false;

  final StreamController<ChargingSessionModel> _sessionStreamController =
      StreamController<ChargingSessionModel>.broadcast();

  Stream<ChargingSessionModel> get sessionStream => _sessionStreamController.stream;

  /// Ensures persisted sessions are loaded on startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load active session if any
      final activeJsonStr = prefs.getString(_prefsActiveSessionKey);
      if (activeJsonStr != null && activeJsonStr.isNotEmpty) {
        final map = jsonDecode(activeJsonStr) as Map<String, dynamic>;
        final loaded = ChargingSessionModel.fromJson(map);
        if (loaded.status.isActive) {
          _activeSession = loaded;
          if (_activeSession!.status == ChargingSessionStatus.charging) {
            _startTimer();
          }
        }
      }

      // Load history
      final historyJsonStr = prefs.getString(_prefsHistoryKey);
      if (historyJsonStr != null && historyJsonStr.isNotEmpty) {
        final List list = jsonDecode(historyJsonStr);
        _sessionHistory = list
            .map((item) => ChargingSessionModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _sessionHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[ChargingSessionService] Initialization error: $e');
      _isInitialized = true;
    }
  }

  /// Get active session.
  Future<ChargingSessionModel?> getActiveSession() async {
    await initialize();
    return _activeSession;
  }

  /// Get session history.
  Future<List<ChargingSessionModel>> getSessionHistory() async {
    await initialize();
    return List.unmodifiable(_sessionHistory);
  }

  /// Start a new simulated EV charging session.
  Future<ChargingSessionModel> startSession({
    required String userId,
    required String chargerId,
    required String chargerName,
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
    await initialize();

    // Check if an active session already exists
    if (_activeSession != null && _activeSession!.status.isActive) {
      throw Exception('A charging session is already in progress.');
    }

    // Validation
    if (initialSocPercent >= targetSocPercent) {
      throw Exception('Target SOC must be greater than current SOC.');
    }
    if (initialSocPercent < 0 || targetSocPercent > 100) {
      throw Exception('Invalid SOC parameters.');
    }

    final now = DateTime.now();
    final sessionId = 'sess_${now.millisecondsSinceEpoch}_${Random().nextInt(1000)}';

    final effectiveMaxPower = min(chargerPowerKw, vehicleMaxPowerKw);

    _activeSession = ChargingSessionModel(
      sessionId: sessionId,
      userId: userId,
      chargerId: chargerId,
      chargerName: chargerName,
      networkName: networkName,
      chargerAddress: chargerAddress,
      vehicleId: vehicleId,
      vehicleName: vehicleName,
      connectorType: connectorType,
      chargerPowerKw: chargerPowerKw,
      chargingMode: chargerPowerKw >= 22.0 ? 'DC Fast' : 'AC Type 2',
      startTime: now,
      initialSocPercent: initialSocPercent,
      currentSocPercent: initialSocPercent,
      targetSocPercent: targetSocPercent,
      batteryCapacityKwh: batteryCapacityKwh,
      energyDeliveredKwh: 0.0,
      estimatedCost: 0.0,
      finalCost: 0.0,
      pricePerKwh: pricePerKwh,
      chargingEfficiency: chargingEfficiency,
      chargingLossKwh: 0.0,
      activePowerKw: effectiveMaxPower,
      status: ChargingSessionStatus.charging,
      createdAt: now,
      updatedAt: now,
      powerGraph: [
        GraphPoint(timestampOffsetSeconds: 0, kwValue: effectiveMaxPower),
      ],
    );

    await _persistActiveSession();
    _sessionStreamController.add(_activeSession!);
    _startTimer();

    return _activeSession!;
  }

  /// Pause current active session.
  Future<ChargingSessionModel> pauseSession([String? sessionId]) async {
    await initialize();
    if (_activeSession == null) throw Exception('No active charging session.');

    _activeSession = _activeSession!.copyWith(
      status: ChargingSessionStatus.paused,
      activePowerKw: 0.0,
      updatedAt: DateTime.now(),
    );

    _stopTimer();
    await _persistActiveSession();
    _sessionStreamController.add(_activeSession!);
    return _activeSession!;
  }

  /// Resume paused charging session.
  Future<ChargingSessionModel> resumeSession([String? sessionId]) async {
    await initialize();
    if (_activeSession == null) throw Exception('No active charging session.');

    _activeSession = _activeSession!.copyWith(
      status: ChargingSessionStatus.charging,
      updatedAt: DateTime.now(),
    );

    await _persistActiveSession();
    _sessionStreamController.add(_activeSession!);
    _startTimer();
    return _activeSession!;
  }

  /// Stop charging session manually.
  Future<ChargingSessionModel> stopSession([String? sessionId]) async {
    await initialize();
    if (_activeSession == null) throw Exception('No active charging session.');

    _stopTimer();
    final now = DateTime.now();

    // Calculate final billing amounts
    final gridEnergyKwh = _activeSession!.gridEnergyDrawnKwh;
    final finalCost = (gridEnergyKwh * _activeSession!.pricePerKwh).roundToDouble();

    _activeSession = _activeSession!.copyWith(
      status: ChargingSessionStatus.paymentPending,
      endTime: now,
      activePowerKw: 0.0,
      finalCost: max(10.0, finalCost > 0 ? finalCost : _activeSession!.estimatedCost),
      updatedAt: now,
    );

    await _persistActiveSession();
    _sessionStreamController.add(_activeSession!);
    return _activeSession!;
  }

  /// Auto-completes when target SOC is reached.
  Future<ChargingSessionModel> completeSession([String? sessionId]) async {
    return stopSession(sessionId);
  }

  /// Cancel session prior to charging or during error.
  Future<ChargingSessionModel> cancelSession([String? sessionId]) async {
    await initialize();
    if (_activeSession == null) throw Exception('No active charging session.');

    _stopTimer();
    final now = DateTime.now();
    _activeSession = _activeSession!.copyWith(
      status: ChargingSessionStatus.cancelled,
      endTime: now,
      activePowerKw: 0.0,
      updatedAt: now,
    );

    _addToHistory(_activeSession!);
    await _clearActiveSessionStorage();
    _sessionStreamController.add(_activeSession!);
    final cancelled = _activeSession!;
    _activeSession = null;
    return cancelled;
  }

  /// Called after successful wallet payment confirmation.
  Future<ChargingSessionModel> markPaymentSuccessful({
    required String transactionId,
    required String referenceId,
  }) async {
    await initialize();
    if (_activeSession == null) throw Exception('No active session for payment.');

    final now = DateTime.now();
    _activeSession = _activeSession!.copyWith(
      status: ChargingSessionStatus.completed,
      transactionId: transactionId,
      referenceId: referenceId,
      updatedAt: now,
    );

    _addToHistory(_activeSession!);
    await _clearActiveSessionStorage();
    _sessionStreamController.add(_activeSession!);
    final completed = _activeSession!;
    _activeSession = null;
    return completed;
  }

  /// Called when wallet payment fails (e.g. insufficient funds).
  Future<ChargingSessionModel> markPaymentFailed(String errorReason) async {
    await initialize();
    if (_activeSession == null) throw Exception('No active session.');

    _activeSession = _activeSession!.copyWith(
      status: ChargingSessionStatus.paymentFailed,
      updatedAt: DateTime.now(),
    );

    await _persistActiveSession();
    _sessionStreamController.add(_activeSession!);
    return _activeSession!;
  }

  /// Clears completed/cancelled session from active state.
  Future<void> clearActiveSession() async {
    _stopTimer();
    await _clearActiveSessionStorage();
    _activeSession = null;
  }

  /// Legacy helper method for old callers streaming simulation.
  Stream<ChargingSessionModel> startSimulatedSession(ChargingSessionModel initialSession) {
    startSession(
      userId: initialSession.userId,
      chargerId: initialSession.chargerId,
      chargerName: initialSession.chargerName,
      chargerPowerKw: initialSession.chargerPowerKw,
    );
    return sessionStream;
  }

  void stopSimulation() {
    _stopTimer();
  }

  // ─── Simulation Engine & Power Curve Tapering Math ───────────────────────

  void _startTimer() {
    _stopTimer();
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tickSimulation();
    });
  }

  void _stopTimer() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _tickSimulation() {
    if (_activeSession == null || _activeSession!.status != ChargingSessionStatus.charging) {
      _stopTimer();
      return;
    }

    final s = _activeSession!;

    // 1. Tapering Math based on current SOC
    double effectivePowerKw = s.chargerPowerKw;
    if (s.currentSocPercent >= 90.0) {
      effectivePowerKw = s.chargerPowerKw * 0.20; // 20% power taper above 90%
    } else if (s.currentSocPercent >= 80.0) {
      effectivePowerKw = s.chargerPowerKw * 0.50; // 50% power taper above 80%
    }

    // Add minor random fluctuation (± 2%)
    final randomFluctuation = (Random().nextDouble() * 0.04 - 0.02) * effectivePowerKw;
    final livePowerKw = max(1.0, effectivePowerKw + randomFluctuation);

    // 2. Calculate Energy Delivered in 1 second simulation tick
    // Fast simulation speed: 1 sec tick = 0.5 kWh equivalent progress for demo responsiveness
    final energyAddedThisTickKwh = (livePowerKw / 3600.0) * 15.0; // 15x accelerated for demo
    final newEnergyDeliveredKwh = s.energyDeliveredKwh + energyAddedThisTickKwh;

    // 3. Calculate SOC Increase
    final socIncreasePct = (energyAddedThisTickKwh / s.batteryCapacityKwh) * 100.0;
    final newSocPct = min(s.targetSocPercent, s.currentSocPercent + socIncreasePct);

    // 4. Calculate Efficiency Loss & Grid Energy
    final newLossKwh = newEnergyDeliveredKwh * (1.0 - s.chargingEfficiency);
    final gridEnergyKwh = newEnergyDeliveredKwh / s.chargingEfficiency;
    final newEstimatedCost = gridEnergyKwh * s.pricePerKwh;

    // 5. Update graph points
    final elapsedSec = DateTime.now().difference(s.startTime).inSeconds;
    final updatedGraph = List<GraphPoint>.from(s.powerGraph);
    if (elapsedSec % 2 == 0) {
      updatedGraph.add(GraphPoint(timestampOffsetSeconds: elapsedSec, kwValue: livePowerKw));
    }

    // Check if target SOC reached
    if (newSocPct >= s.targetSocPercent) {
      _stopTimer();
      _activeSession = s.copyWith(
        currentSocPercent: s.targetSocPercent,
        energyDeliveredKwh: newEnergyDeliveredKwh,
        chargingLossKwh: newLossKwh,
        estimatedCost: newEstimatedCost,
        finalCost: newEstimatedCost,
        activePowerKw: 0.0,
        status: ChargingSessionStatus.completing,
        endTime: DateTime.now(),
        updatedAt: DateTime.now(),
        powerGraph: updatedGraph,
      );
      _persistActiveSession();
      _sessionStreamController.add(_activeSession!);
      return;
    }

    _activeSession = s.copyWith(
      currentSocPercent: newSocPct,
      energyDeliveredKwh: newEnergyDeliveredKwh,
      chargingLossKwh: newLossKwh,
      estimatedCost: newEstimatedCost,
      activePowerKw: livePowerKw,
      updatedAt: DateTime.now(),
      powerGraph: updatedGraph,
    );

    _persistActiveSession();
    _sessionStreamController.add(_activeSession!);
  }

  // ─── Persistence Helper Methods ──────────────────────────────────────────

  Future<void> _persistActiveSession() async {
    if (_activeSession == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsActiveSessionKey, jsonEncode(_activeSession!.toJson()));
    } catch (e) {
      debugPrint('[ChargingSessionService] Persist active session error: $e');
    }
  }

  Future<void> _clearActiveSessionStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsActiveSessionKey);
    } catch (_) {}
  }

  void _addToHistory(ChargingSessionModel session) async {
    _sessionHistory.removeWhere((item) => item.sessionId == session.sessionId);
    _sessionHistory.insert(0, session);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _sessionHistory.map((item) => item.toJson()).toList();
      await prefs.setString(_prefsHistoryKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[ChargingSessionService] Persist history error: $e');
    }
  }
}
