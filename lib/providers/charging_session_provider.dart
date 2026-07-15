import 'dart:async';
import 'package:flutter/material.dart';
import '../models/charging_session_model.dart';
import '../repositories/charging_session_repository.dart';
import '../services/charging_session_service.dart';

class ChargingSessionProvider extends ChangeNotifier {
  final ChargingSessionRepository _repository;
  final ChargingSessionService _service;

  ChargingSessionModel? _activeSession;
  StreamSubscription<ChargingSessionModel>? _simulationSubscription;
  bool _isLoading = false;

  ChargingSessionProvider({
    required ChargingSessionRepository repository,
    required ChargingSessionService service,
  })  : _repository = repository,
        _service = service;

  ChargingSessionModel? get activeSession => _activeSession;
  bool get isLoading => _isLoading;
  bool get isCharging => _activeSession?.status == SessionStatus.charging;
  bool get isPaused => _activeSession?.status == SessionStatus.paused;

  Future<void> startSession(String userId, String stationId, String chargerId) async {
    _isLoading = true;
    notifyListeners();

    final session = ChargingSessionModel(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      stationId: stationId,
      chargerId: chargerId,
      startTime: DateTime.now(),
      status: SessionStatus.charging,
    );

    await _repository.saveSession(session);
    _activeSession = session;

    _simulationSubscription?.cancel();
    _simulationSubscription = _service.startSimulatedSession(session).listen((updatedSession) {
      _activeSession = updatedSession;
      _repository.updateSessionState(updatedSession);
      notifyListeners();

      if (updatedSession.status == SessionStatus.completed || updatedSession.status == SessionStatus.stopped) {
        _simulationSubscription?.cancel();
      }
    });

    _isLoading = false;
    notifyListeners();
  }

  void pauseSession() {
    if (_activeSession != null) {
      _activeSession = _activeSession!.copyWith(status: SessionStatus.paused);
      _repository.updateSessionState(_activeSession!);
      notifyListeners();
    }
  }

  void resumeSession() {
    if (_activeSession != null) {
      _activeSession = _activeSession!.copyWith(status: SessionStatus.charging);
      _repository.updateSessionState(_activeSession!);
      notifyListeners();
    }
  }

  void stopSession() {
    if (_activeSession != null) {
      _service.stopSimulation();
      _activeSession = _activeSession!.copyWith(
        status: SessionStatus.stopped,
        endTime: DateTime.now(),
        currentKw: 0.0,
      );
      _repository.updateSessionState(_activeSession!);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _simulationSubscription?.cancel();
    _service.stopSimulation();
    super.dispose();
  }
}
