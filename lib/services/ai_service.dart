import '../models/chat_message.dart';

class AIService {
  /// Generate a response using an AI model.
  /// This is currently an intelligent mock that can be replaced with the Gemini API later.
  Future<ChatMessage> generateResponse(String prompt) async {
    // Simulate thinking delay
    await Future.delayed(const Duration(seconds: 2));

    String responseText = '';
    List<String>? suggestions;

    final lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.contains('charge') || lowerPrompt.contains('station')) {
      responseText = 'There are 3 fast charging stations within a 10km radius. Tata Power EZ Charge at Phoenix Mall is currently available.';
      suggestions = ['Navigate there', 'Show pricing', 'Other stations'];
    } else if (lowerPrompt.contains('trip') || lowerPrompt.contains('route')) {
      responseText = 'Planning a trip to Pune? You should charge to at least 80% before leaving. You might need one stop at the Lonavala food court charger.';
      suggestions = ['Plan this route', 'Check chargers on route'];
    } else if (lowerPrompt.contains('health') || lowerPrompt.contains('battery')) {
      responseText = 'Your battery health looks great at 96.5%. Try keeping it between 20-80% for daily commutes to prolong its life.';
      suggestions = ['Show Battery Health Center', 'Tips for summer'];
    } else {
      responseText = 'I am your EVHub AI Assistant. I can help you plan trips, find chargers, or analyze your vehicle\'s battery health. How can I help you today?';
      suggestions = ['Find nearby chargers', 'Check battery health', 'Plan a trip'];
    }

    return ChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      message: responseText,
      timestamp: DateTime.now(),
      suggestedPrompts: suggestions,
    );
  }
}
