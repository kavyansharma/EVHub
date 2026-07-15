import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { topup, charge, refund }

class TransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  bool get isCredit => type == TransactionType.topup || type == TransactionType.refund;

  String get formattedAmount =>
      '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}';

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: _typeFromString(data['type'] ?? 'charge'),
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  static TransactionType _typeFromString(String s) {
    switch (s) {
      case 'topup':
        return TransactionType.topup;
      case 'refund':
        return TransactionType.refund;
      default:
        return TransactionType.charge;
    }
  }
}
