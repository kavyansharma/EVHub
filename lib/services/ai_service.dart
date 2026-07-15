import '../models/chat_message.dart';

class AIService {
  // TODO: Integrate google_generative_ai package
  // late final GenerativeModel _model;

  void initialize(String apiKey) {
    // _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
  }

  /// Phase 5 Module 6: Generate response with Memory/History context.
  Future<ChatMessage> generateResponse(String prompt, {List<ChatMessage>? history}) async {
    // TODO: _model.generateContent() utilizing history parameter
    
    await Future.delayed(const Duration(seconds: 2));

    String responseText = '';
    List<String>? suggestions;
    String? assignedTag;

    final lowerPrompt = prompt.toLowerCase();
    
    // Check history for context if the current prompt is vague
    bool historyIsTrip = false;
    if (history != null && history.isNotEmpty) {
      if (history.last.contextTag == 'trip_planning') {
        historyIsTrip = true;
      }
    }
    
    if (lowerPrompt.contains('charge') || lowerPrompt.contains('station')) {
      responseText = 'There are 3 fast charging stations within a 10km radius. Tata Power EZ Charge at Phoenix Mall is currently available.';
      suggestions = ['Navigate there', 'Show pricing', 'Other stations'];
      assignedTag = 'charging_stations';
    } else if (lowerPrompt.contains('trip') || lowerPrompt.contains('route') || (historyIsTrip && lowerPrompt.contains('yes'))) {
      responseText = 'Planning a trip to Pune? You should charge to at least 80% before leaving. I have considered elevation and heavy traffic, so you might need one stop at the Lonavala food court charger.';
      suggestions = ['Plan this route', 'Check chargers on route'];
      assignedTag = 'trip_planning';
    } else if (lowerPrompt.contains('health') || lowerPrompt.contains('battery')) {
      responseText = 'Your battery health looks great at 96.5%. Try keeping it between 20-80% for daily commutes to prolong its life.';
      suggestions = ['Show Battery Health Center', 'Tips for summer'];
      assignedTag = 'battery_health';
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
      contextTag: assignedTag,
    );
  }
}
