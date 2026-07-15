import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Manages user profile documents in Firestore /users/{uid}.
abstract class UserRepository {
  Future<void> createUserDocument(UserModel user);
  Future<void> updateUserDocument(String uid, Map<String, dynamic> data);
  Future<UserModel?> getUserDocument(String uid);
  Stream<UserModel?> watchUserDocument(String uid);
}

class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _firestore;

  UserRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _usersCol =>
      _firestore.collection(AppConstants.colUsers);

  @override
  Future<void> createUserDocument(UserModel user) async {
    await _usersCol.doc(user.id).set(user.toFirestore(), SetOptions(merge: true));

    // Also create a wallet document if it doesn't exist yet.
    final walletDoc = _firestore
        .collection(AppConstants.colWallets)
        .doc(user.id);
    final snap = await walletDoc.get();
    if (!snap.exists) {
      await walletDoc.set({
        'balance': 1250.0,
        'currency': 'INR',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> updateUserDocument(String uid, Map<String, dynamic> data) async {
    await _usersCol.doc(uid).update(data);
  }

  @override
  Future<UserModel?> getUserDocument(String uid) async {
    final snap = await _usersCol.doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  @override
  Stream<UserModel?> watchUserDocument(String uid) {
    return _usersCol.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }
}
