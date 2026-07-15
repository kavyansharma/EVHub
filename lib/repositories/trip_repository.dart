import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/trip_history_model.dart';

/// Manages trip planning history in Firestore.
abstract class TripRepository {
  Future<void> saveTripHistory(TripHistoryModel trip);
  Stream<List<TripHistoryModel>> watchTripHistory(String uid);
}

class TripRepositoryImpl implements TripRepository {
  final FirebaseFirestore _firestore;

  TripRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _tripsCol =>
      _firestore.collection(AppConstants.colTripHistory);

  @override
  Future<void> saveTripHistory(TripHistoryModel trip) async {
    await _tripsCol.add(trip.toFirestore());
  }

  @override
  Stream<List<TripHistoryModel>> watchTripHistory(String uid) {
    return _tripsCol
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TripHistoryModel.fromFirestore(doc))
            .toList());
  }
}
