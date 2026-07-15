import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

/// Manages wallet balance and transactions in Firestore.
abstract class WalletRepository {
  Stream<WalletModel?> watchWallet(String uid);
  Future<void> topUp(String uid, double amount, String description);
  Future<void> deduct(String uid, double amount, String description);
  Stream<List<TransactionModel>> watchTransactions(String uid);
}

class WalletRepositoryImpl implements WalletRepository {
  final FirebaseFirestore _firestore;

  WalletRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference _walletDoc(String uid) =>
      _firestore.collection(AppConstants.colWallets).doc(uid);

  CollectionReference get _txCol =>
      _firestore.collection(AppConstants.colTransactions);

  @override
  Stream<WalletModel?> watchWallet(String uid) {
    return _walletDoc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return WalletModel.fromFirestore(snap);
    });
  }

  @override
  Future<void> topUp(String uid, double amount, String description) async {
    await _firestore.runTransaction((txn) async {
      final walletRef = _walletDoc(uid);
      final snap = await txn.get(walletRef);

      final currentBalance = snap.exists
          ? (snap.data() as Map<String, dynamic>)['balance'] as double? ?? 0.0
          : 0.0;

      // Update wallet balance atomically.
      txn.set(
        walletRef,
        {
          'balance': currentBalance + amount,
          'currency': 'INR',
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Write transaction record.
      txn.set(
        _txCol.doc(),
        {
          'userId': uid,
          'type': TransactionType.topup.name,
          'amount': amount,
          'description': description,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  @override
  Future<void> deduct(String uid, double amount, String description) async {
    await _firestore.runTransaction((txn) async {
      final walletRef = _walletDoc(uid);
      final snap = await txn.get(walletRef);

      final currentBalance = snap.exists
          ? (snap.data() as Map<String, dynamic>)['balance'] as double? ?? 0.0
          : 0.0;

      if (currentBalance < amount) {
        throw Exception('Insufficient wallet balance.');
      }

      txn.set(
        walletRef,
        {
          'balance': currentBalance - amount,
          'currency': 'INR',
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      txn.set(
        _txCol.doc(),
        {
          'userId': uid,
          'type': TransactionType.charge.name,
          'amount': amount,
          'description': description,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  @override
  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _txCol
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }
}
