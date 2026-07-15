import 'package:flutter/material.dart';
import '../models/charging_session.dart';
import '../repositories/history_repository.dart';

class HistoryProvider extends ChangeNotifier {
  final HistoryRepository _historyRepository;
  
  List<ChargingSession> _sessions = [];
  bool _isLoading = false;

  HistoryProvider({required HistoryRepository historyRepository}) 
    : _historyRepository = historyRepository;

  List<ChargingSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> fetchHistory(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _sessions = await _historyRepository.getChargingHistory(userId);
    } catch (e) {
      debugPrint("Error fetching history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSession(String userId, ChargingSession session) async {
    try {
      await _historyRepository.addChargingSession(userId, session);
      await fetchHistory(userId); // Refresh list
    } catch (e) {
      debugPrint("Error adding session: $e");
    }
  }
}
