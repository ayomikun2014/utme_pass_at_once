import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';

class AIService {
  // 1. Define the System Instruction (The AI's "Personality")
  static const String _systemInstruction = r'''
    You are a highly intelligent, straightforward AI tutor for Nigerian students preparing for JAMB, WAEC, NECO, and Post-UTME. Act naturally, concisely, and directly, similar to a standard AI assistant.

    CRITICAL RULES:
    1. STRICTLY NO MARKDOWN: You are strictly forbidden from using asterisks (*) for bolding, italics, or bullet points. NEVER output "**". If you need to emphasize a section heading, use ALL CAPS instead (e.g., write "STEP 1:" instead of "**Step 1:**"). Use standard numbers (1., 2.) or hyphens (-) for lists.
    2. GREETING LOGIC: ONLY output your welcome message ("Welcome to PASS AT ONCE CBT! I am your AI Teacher. How can I help you excel in your studies today? 🎓") if the user's prompt is EXCLUSIVELY a simple greeting (e.g., "Hi", "Hello", "Good morning"). If the user prompt contains a question, a math problem, or any other request, DO NOT greet them. Start solving the problem immediately.
    3. MATH & LATEX:
       - Use LaTeX for mathematical formulas and equations.
       - Use \( ... \) for inline math and \[ ... \] for block equations.
       - NEVER use dollar signs ($) for math to avoid currency formatting issues.
    4. PROBLEM SOLVING: Provide clear, step-by-step solutions for all secondary school subjects. Get straight to the point without unnecessary fluff.
  ''';

  // 2. Manage Chat History for Context
  final List<Map<String, String>> _chatHistory = [];

  AIService() {
    // 3. Initialize the Chat Session with System Instructions
    resetChatMemory();
  }

  Future<String> getAIResponse(String userPrompt) async {
    // Add the student's new message to the history
    _chatHistory.add({"role": "user", "content": userPrompt});

    try {
      // Make the REST API call to Groq
      debugPrint(
        "TESTING KEY: ${Env.groqApiKey}",
      ); // DELETE THIS AFTER TESTING!
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          // Make sure to use your new Groq API variable here
          'Authorization': 'Bearer ${Env.groqApiKey}',
        },
        body: jsonEncode({
          // Using Groq's incredibly fast Llama 3.3 70B model
          'model': 'llama-3.3-70b-versatile',
          'messages': _chatHistory,
          'temperature': 0.7,
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'] as String;

        // Add Cognita's response back to the history so it remembers what it said
        _chatHistory.add({"role": "assistant", "content": aiMessage});

        return aiMessage;
      } else {
        debugPrint(
          "DEBUG GROQ ERROR: ${response.statusCode} - ${response.body}",
        );
        // Remove the user's message from history if the request failed so they can try again
        _chatHistory.removeLast();
        return "Connection error. Please try again later.";
      }
    } catch (e) {
      debugPrint("DEBUG GROQ EXCEPTION: $e");
      _chatHistory.removeLast();
      return "Connection error. Please check your internet.";
    }
  }

  // Helper method to clear the chat memory
  void resetChatMemory() {
    _chatHistory.clear();
    // Always start with the system instruction telling it how to behave
    _chatHistory.add({"role": "system", "content": _systemInstruction});
  }
}
