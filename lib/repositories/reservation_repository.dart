import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_model.dart';

class ReservationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createReservation(ReservationModel reservation) async {
    await _firestore
        .collection('reservations')
        .doc(reservation.id)
        .set(reservation.toMap());
  }

  Future<List<ReservationModel>> getUserReservations(String userId) async {
    final snapshot = await _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => ReservationModel.fromFirestore(doc)).toList();
  }

  Future<void> updateReservationStatus(String reservationId, ReservationStatus status) async {
    await _firestore
        .collection('reservations')
        .doc(reservationId)
        .update({'status': status.name});
  }

  Stream<List<ReservationModel>> listenToUserReservations(String userId) {
    return _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReservationModel.fromFirestore(doc)).toList());
  }
}
