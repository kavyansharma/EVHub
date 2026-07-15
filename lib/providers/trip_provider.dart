import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_history_model.dart';
import '../repositories/trip_repository.dart';

/// Provides trip planning history from Firestore.
class TripProvider extends ChangeNotifier {
  final TripRepository _tripRepository;

  List<TripHistoryModel> _tripHistory = [];
  final bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<TripHistoryModel>>? _tripSub;

  TripProvider({required TripRepository tripRepository})
      : _tripRepository = tripRepository;

  // ─── Getters ───────────────────────────────────────────────────────────────

  List<TripHistoryModel> get tripHistory => List.unmodifiable(_tripHistory);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  void loadForUser(String uid) {
    _tripSub?.cancel();
    _tripSub = _tripRepository.watchTripHistory(uid).listen(
      (trips) {
        _tripHistory = trips;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  void clear() {
    _tripSub?.cancel();
    _tripHistory = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> saveTrip(TripHistoryModel trip) async {
    try {
      await _tripRepository.saveTripHistory(trip);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    super.dispose();
  }
}
