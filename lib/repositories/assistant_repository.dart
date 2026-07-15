import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';

class AssistantRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AIService _aiService;

  AssistantRepository({required AIService aiService}) : _aiService = aiService;

  Future<ChatMessage> getAIResponse(String prompt) async {
    return await _aiService.generateResponse(prompt);
  }

  Future<void> saveMessage(String userId, ChatMessage message) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chatHistory')
        .doc(message.id)
        .set(message.toMap());
  }

  Future<List<ChatMessage>> getChatHistory(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chatHistory')
        .orderBy('timestamp', descending: true)
        .limit(50) // Limit to recent 50 messages
        .get();
        
    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }
}
