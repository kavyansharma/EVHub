import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_history_model.dart';
import '../models/trip_plan_model.dart';
import '../repositories/trip_repository.dart';
import '../services/directions_service.dart';

/// Provides trip planning history from Firestore.
class TripProvider extends ChangeNotifier {
  final TripRepository _tripRepository;
  final DirectionsService _directionsService;

  List<TripHistoryModel> _tripHistory = [];
  List<TripPlanModel> _advancedTrips = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<TripHistoryModel>>? _tripSub;
  StreamSubscription<List<TripPlanModel>>? _advancedTripSub;

  TripProvider({
    required TripRepository tripRepository,
    required DirectionsService directionsService,
  })  : _tripRepository = tripRepository,
        _directionsService = directionsService;

  // ─── Getters ───────────────────────────────────────────────────────────────

  List<TripHistoryModel> get tripHistory => List.unmodifiable(_tripHistory);
  List<TripPlanModel> get advancedTrips => List.unmodifiable(_advancedTrips);
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
    
    _advancedTripSub?.cancel();
    _advancedTripSub = _tripRepository.watchAdvancedTripPlans(uid).listen(
      (trips) {
        _advancedTrips = trips;
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

  Future<TripPlanModel?> planAdvancedTrip({
    required String userId,
    required String destination,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required double currentBatteryPct,
    required double vehicleEfficiency,
    required double batteryCapacityKw,
    String weatherImpact = 'Clear',
    String elevationImpact = 'Flat',
    String trafficImpact = 'Normal',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final basePlan = TripPlanModel(
        id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        destination: destination,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        weatherImpact: weatherImpact,
        elevationImpact: elevationImpact,
        trafficImpact: trafficImpact,
        plannedDate: DateTime.now(),
      );

      final advancedPlan = await _directionsService.calculateAdvancedTrip(
        basePlan: basePlan,
        currentBatteryPct: currentBatteryPct,
        vehicleEfficiency: vehicleEfficiency,
        batteryCapacityKw: batteryCapacityKw,
      );

      await _tripRepository.saveTripPlan(advancedPlan);
      _isLoading = false;
      notifyListeners();
      return advancedPlan;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    super.dispose();
  }
}
