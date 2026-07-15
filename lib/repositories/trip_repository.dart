import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/trip_history_model.dart';
import '../models/trip_plan_model.dart';

/// Manages trip planning history in Firestore.
abstract class TripRepository {
  Future<void> saveTripHistory(TripHistoryModel trip);
  Stream<List<TripHistoryModel>> watchTripHistory(String uid);
  
  // Phase 5 Module 5: Advanced Trip Plans
  Future<void> saveTripPlan(TripPlanModel tripPlan);
  Stream<List<TripPlanModel>> watchAdvancedTripPlans(String uid);
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

  @override
  Future<void> saveTripPlan(TripPlanModel tripPlan) async {
    await _firestore
        .collection('trip_plans')
        .doc(tripPlan.id)
        .set(tripPlan.toMap());
  }

  @override
  Stream<List<TripPlanModel>> watchAdvancedTripPlans(String uid) {
    return _firestore
        .collection('trip_plans')
        .where('userId', isEqualTo: uid)
        .orderBy('plannedDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TripPlanModel.fromFirestore(doc))
            .toList());
  }
}
