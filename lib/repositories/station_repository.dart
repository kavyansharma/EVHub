import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/charging_history_model.dart';
import '../models/station_model.dart';

/// Manages charging stations, favorites, and charging history in Firestore.
abstract class StationRepository {
  /// Seeds the stations collection if empty.
  Future<void> seedStationsIfEmpty(List<StationModel> stations);

  /// Live stream of all stations.
  Stream<List<StationModel>> watchStations();

  /// Add or remove a station from the user's favorites.
  Future<void> toggleFavorite(String uid, StationModel station);

  /// Live stream of the user's favorite station IDs.
  Stream<Set<String>> watchFavoriteIds(String uid);

  /// Add a charging session record.
  Future<void> addChargingHistory(ChargingHistoryModel entry);

  /// Live stream of the user's charging history.
  Stream<List<ChargingHistoryModel>> watchChargingHistory(String uid);
}

class StationRepositoryImpl implements StationRepository {
  final FirebaseFirestore _firestore;

  StationRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _stationsCol =>
      _firestore.collection(AppConstants.colStations);

  CollectionReference get _favoritesCol =>
      _firestore.collection(AppConstants.colFavorites);

  CollectionReference get _chargingCol =>
      _firestore.collection(AppConstants.colChargingHistory);

  @override
  Future<void> seedStationsIfEmpty(List<StationModel> stations) async {
    final snap = await _stationsCol.limit(1).get();
    if (snap.docs.isNotEmpty) return; // Already seeded.

    final batch = _firestore.batch();
    for (final st in stations) {
      batch.set(_stationsCol.doc(st.id), st.toFirestore());
    }
    await batch.commit();
  }

  @override
  Stream<List<StationModel>> watchStations() {
    // Phase 4/5: Real-time streams via Firestore snapshots.
    // This now supports occupiedStalls, queueLength, etc., automatically updating the UI.
    
    return _stationsCol.snapshots().map(
          (snap) => snap.docs
              .map((doc) => StationModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<void> toggleFavorite(String uid, StationModel station) async {
    // Use composite doc ID to easily check existence.
    final docId = '${uid}_${station.id}';
    final ref = _favoritesCol.doc(docId);
    final snap = await ref.get();

    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': uid,
        'stationId': station.id,
        'stationName': station.name,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Stream<Set<String>> watchFavoriteIds(String uid) {
    return _favoritesCol
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                (doc.data() as Map<String, dynamic>)['stationId'] as String)
            .toSet());
  }

  @override
  Future<void> addChargingHistory(ChargingHistoryModel entry) async {
    await _chargingCol.add(entry.toFirestore());
  }

  @override
  Stream<List<ChargingHistoryModel>> watchChargingHistory(String uid) {
    return _chargingCol
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChargingHistoryModel.fromFirestore(doc))
            .toList());
  }
}
