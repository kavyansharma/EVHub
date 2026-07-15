import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../repositories/assistant_repository.dart';

class AssistantProvider extends ChangeNotifier {
  final AssistantRepository _assistantRepository;

  List<ChatMessage> _messages = [];
  bool _isTyping = false;

  AssistantProvider({required AssistantRepository assistantRepository})
      : _assistantRepository = assistantRepository;

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;

  Future<void> loadHistory(String userId) async {
    try {
      _messages = await _assistantRepository.getChatHistory(userId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
  }

  Future<void> sendMessage(String userId, String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      isUser: true,
      message: text,
      timestamp: DateTime.now(),
    );

    _messages.insert(0, userMessage);
    _isTyping = true;
    notifyListeners();

    try {
      // Save user message
      await _assistantRepository.saveMessage(userId, userMessage);

      // Get AI response
      final aiMessage = await _assistantRepository.getAIResponse(text);
      
      _messages.insert(0, aiMessage);
      await _assistantRepository.saveMessage(userId, aiMessage);
    } catch (e) {
      debugPrint("Error getting AI response: $e");
      final errorMessage = ChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        message: 'Sorry, I am having trouble connecting right now. Please try again later.',
        timestamp: DateTime.now(),
      );
      _messages.insert(0, errorMessage);
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}
