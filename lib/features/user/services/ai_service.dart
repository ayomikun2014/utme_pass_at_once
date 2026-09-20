import 'package:flutter/foundation.dart';
import '../../../core/services/backend_api.dart';

/// The AI tutor.
///
/// The question goes to the backend, which holds the model key and answers
/// with the reply. Nothing secret is carried in the app.
class AIService {
  /// What has been said so far, so the tutor can follow the thread.
  final List<Map<String, String>> _chatHistory = [];

  Future<String> getAIResponse(String userPrompt) async {
    try {
      final data = await BackendApi.post(
        'ai/chat',
        {'prompt': userPrompt, 'history': _chatHistory},
        const Duration(seconds: 90),
      );

      final answer = (data['answer'] ?? '').toString().trim();
      if (answer.isEmpty) {
        return "The tutor gave no answer. Please try again.";
      }

      _chatHistory
        ..add({"role": "user", "content": userPrompt})
        ..add({"role": "assistant", "content": answer});
      // Keep the thread from growing without end.
      if (_chatHistory.length > 24) {
        _chatHistory.removeRange(0, _chatHistory.length - 24);
      }
      return answer;
    } on BackendException catch (e) {
      debugPrint("AI tutor error: $e");
      return e.statusCode == 429
          ? "You have asked a lot of questions this hour. Please try again later."
          : "Connection error. Please check your internet and try again.";
    } catch (e) {
      debugPrint("AI tutor error: $e");
      return "Connection error. Please check your internet.";
    }
  }

  /// Start a fresh conversation.
  void resetChatMemory() {
    _chatHistory.clear();
  }
}
