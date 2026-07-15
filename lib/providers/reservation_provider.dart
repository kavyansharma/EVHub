import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';
import '../services/reservation_service.dart';

class ReservationProvider extends ChangeNotifier {
  final ReservationRepository _reservationRepository;
  final ReservationService _reservationService;

  List<ReservationModel> _reservations = [];
  bool _isLoading = false;

  ReservationProvider({
    required ReservationRepository reservationRepository,
    required ReservationService reservationService,
  })  : _reservationRepository = reservationRepository,
        _reservationService = reservationService;

  List<ReservationModel> get reservations => _reservations;
  bool get isLoading => _isLoading;

  void listenToReservations(String userId) {
    _reservationRepository.listenToUserReservations(userId).listen((data) {
      _reservations = data;
      notifyListeners();
    });
  }

  Future<bool> createReservation({
    required String userId,
    required String stationId,
    required String chargerId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_reservationService.validateReservationTime(start, end)) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final cost = _reservationService.calculateReservationCost(start, end, 1.5);
      final reservation = ReservationModel(
        id: 'res_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        stationId: stationId,
        chargerId: chargerId,
        startTime: start,
        endTime: end,
        status: ReservationStatus.pending,
        createdAt: DateTime.now(),
        estimatedCost: cost,
      );

      await _reservationRepository.createReservation(reservation);
      return true;
    } catch (e) {
      debugPrint("Error creating reservation: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelReservation(String reservationId) async {
    await _reservationRepository.updateReservationStatus(reservationId, ReservationStatus.cancelled);
  }
}
