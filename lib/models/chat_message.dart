import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String message;
  final DateTime timestamp;
  final List<String>? suggestedPrompts;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.message,
    required this.timestamp,
    this.suggestedPrompts,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      isUser: data['isUser'] ?? false,
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      suggestedPrompts: data['suggestedPrompts'] != null
          ? List<String>.from(data['suggestedPrompts'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isUser': isUser,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      if (suggestedPrompts != null) 'suggestedPrompts': suggestedPrompts,
    };
  }
}
