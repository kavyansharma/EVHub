import 'package:flutter/foundation.dart';
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
    debugPrint('[UserRepository] Creating /users/${user.id} profile (role=${user.role.name})...');
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
    debugPrint('[UserRepository] Updating /users/$uid with $data');
    await _usersCol.doc(uid).update(data);
  }

  @override
  Future<UserModel?> getUserDocument(String uid) async {
    debugPrint('[UserRepository] Fetching /users/$uid document from Firestore...');
    try {
      final snap = await _usersCol.doc(uid).get();
      if (!snap.exists) {
        debugPrint('[UserRepository] ⚠ Document /users/$uid DOES NOT EXIST in Firestore.');
        return null;
      }
      final user = UserModel.fromFirestore(snap);
      debugPrint('[UserRepository] ✓ Loaded /users/$uid: name="${user.name}", role="${user.role.name}", isAdmin=${user.isAdmin}');
      return user;
    } on FirebaseException catch (e) {
      debugPrint('[UserRepository] ❌ FirebaseException fetching /users/$uid: code=${e.code}, message=${e.message}');
      return null;
    } catch (e) {
      debugPrint('[UserRepository] ❌ Error fetching /users/$uid: $e');
      return null;
    }
  }

  @override
  Stream<UserModel?> watchUserDocument(String uid) {
    return _usersCol.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }
}

