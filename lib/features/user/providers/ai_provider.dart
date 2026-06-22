import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../../../core/services/network_service.dart';

class AIProvider extends ChangeNotifier {
  final AIService _aiService = AIService();

  // Internal list of Messages
  final List<ChatMessage> _messages = [];

  static const String _aiCacheKey = 'cached_ai_messages';

  // Getters
  List<ChatMessage> get messages => _messages;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AIProvider() {
    _loadCachedMessages();
  }

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_aiCacheKey);
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        _messages.clear();
        _messages.addAll(decoded.map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e))));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading cached AI messages: $e");
    }
  }

  Future<void> _saveCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_messages.map((e) => e.toMap()).toList());
      await prefs.setString(_aiCacheKey, jsonStr);
    } catch (e) {
      debugPrint("Error saving cached AI messages: $e");
    }
  }

  // SECURED: Premium status is now injected per-message, not hardcoded globally.
  Future<void> sendMessage(String text, {required bool isPremium}) async {
    if (text.trim().isEmpty) return;

    if (!await NetworkService.instance.hasInternet()) {
      _messages.insert(
        0,
         ChatMessage(text: "You are offline. Please check your internet connection and try again.", isMe: false),
      );
      notifyListeners();
      return;
    }

    _messages.insert(0, ChatMessage(text: text, isMe: true));
    await _saveCachedMessages();
    notifyListeners();

    // Start Loading/Typing state
    _isLoading = true;
    notifyListeners();

    // Secure Premium Check
    if (!isPremium) {
      // Artificial delay to make the "Typing..." feel real
      await Future.delayed(const Duration(seconds: 1));
      _messages.insert(
        0,
         ChatMessage(
          text: "This is a Premium feature. Please buy an Exam to unlock Cognita AI!",
          isMe: false,
        ),
      );
      await _saveCachedMessages();
      _isLoading = false; // Stop loading
      notifyListeners();
      return;
    }

    try {
      final response = await _aiService.getAIResponse(text);
      _messages.insert(0, ChatMessage(text: response, isMe: false));
      await _saveCachedMessages();
    } catch (e) {
      _messages.insert(
        0,
         ChatMessage(text: "Something went wrong. Please try again.", isMe: false),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}