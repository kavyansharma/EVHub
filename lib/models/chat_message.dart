import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String message;
  final DateTime timestamp;
  final List<String>? suggestedPrompts;
  
  // Phase 5 Module 6: AI Charging Assistant Memory
  final String? contextTag; // e.g. "trip_planning", "battery_health"
  final Map<String, dynamic>? memoryMetadata;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.message,
    required this.timestamp,
    this.suggestedPrompts,
    this.contextTag,
    this.memoryMetadata,
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
      contextTag: data['contextTag'],
      memoryMetadata: data['memoryMetadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isUser': isUser,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      if (suggestedPrompts != null) 'suggestedPrompts': suggestedPrompts,
      if (contextTag != null) 'contextTag': contextTag,
      if (memoryMetadata != null) 'memoryMetadata': memoryMetadata,
    };
  }
}
