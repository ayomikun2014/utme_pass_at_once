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

  // Local FAQ dataset for offline instant support (focused strictly on payment, activation, locking and binding)
  static const Map<String, String> localFaqs = {
    'How do I make my payment?':
        'To make a payment for any exam package:\n\n'
        '• Open Buy Activation Code from the Home screen or the More tab.\n'
        '• Select your target Exam Type (UTME, Post-UTME, NECO, or WAEC).\n'
        '• Read the package description and choose the Pay Online (Paystack) payment method.\n'
        '• This redirects you to the Paystack secure gateway where you can pay via Card, USSD, or Bank Transfer.\n'
        '• Once the payment completes successfully, your unique Activation Code will generate and show on the screen immediately for you to copy.\n\n'
        'Note: If the screen closes before you copy the code, go to My Orders on the Home screen to view and copy your PIN.',

    'How do I submit a manual bank transfer?':
        'To pay via direct manual bank transfer:\n\n'
        '• Tap Buy Activation Code and choose the Exam Type you want to purchase.\n'
        '• Under the payment methods, select the Manual Payment option.\n'
        '• Make the transfer to the official bank details displayed on the screen and take a screenshot of the receipt.\n'
        '• Upload your proof of payment screenshot in the field provided and submit.\n'
        '• Once the administrator verifies your transaction, an Activation Code will be generated and will appear under My Orders. Use this code to unlock your exam package.',

    'How do I activate any exam?':
        'Once you have your Activation Code/PIN, you can activate it to unlock premium study materials:\n\n'
        '• Tap the Unlock Now button on the Home screen, or go to My Orders and tap Unlock Now.\n'
        '• Enter your Activation Code/PIN and tap Verify.\n'
        '• Select your target Institution (e.g. OAU, UI, UNILAG) and choose your target Section (Science or Art/Commerce).\n'
        '• Tap the Submit button.\n'
        '• Keep the app open and connected to the internet while it downloads the offline package data files to your device.\n\n'
        'Please note: Active internet is required only during verification and downloading; after activation, all questions and materials work 100% offline.',

    'How do I lock any exam?':
        'When activating your exam package with your Activation Code, you must select your target Institution and study Section:\n\n'
        '• Selecting these details and tapping Submit binds and locks the exam package to that specific selection.\n'
        '• Important: Once submitted, the exam package is permanently locked to that specific Institution and Section and cannot be changed or reset by yourself. Please double-check your school and section selection before clicking submit!',

    'What is the device binding lock policy?':
        'To prevent account sharing and piracy, PASS AT ONCE links your account to the first device you log in on:\n\n'
        '• On your first login, the app automatically binds your device ID to your online account.\n'
        '• If you try to log in on a second device, the system will deny access and display a "This account is locked to another device" error.\n\n'
        'Please note: If you purchased a new phone or need to transfer your registration, please contact our support team at taiwoprints999@gmail.com to request a device binding reset.',

    'How do I force-refresh my premium status?':
        'If you have already activated an exam package but premium features still appear locked:\n\n'
        '• Tap the More tab on the bottom navigation bar and select My Account.\n'
        '• Locate and tap the Refresh Status button (or pull down to refresh on the home dashboard).\n'
        '• The app will sync with the server to pull down your latest subscription state and upgrade your app accordingly.',

    'How do I learn more about the app?':
        'To learn more about the app and explore additional details:\n\n'
        '• Tap the More tab on the bottom navigation bar (the last icon on the right).\n'
        '• Scroll down and tap on Settings.\n'
        '• Under Settings, select the Help & FAQ option to view detailed guidelines and information about app features.',
  };

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

  // Helper to match user text against local FAQs
  String? _findMatchingFaqAnswer(String text) {
    final query = text.toLowerCase().trim();

    // Exact match lookup
    for (final entry in localFaqs.entries) {
      if (entry.key.toLowerCase().trim() == query) {
        return entry.value;
      }
    }

    // Keyword-based lookup
    if (query.contains('device binding') || query.contains('device lock') || query.contains('locked') || query.contains('another device')) {
      return localFaqs['What is the device binding lock policy?'];
    }
    if (query.contains('paystack') || query.contains('pay online') || query.contains('how to make my payment') || query.contains('how do i make my payment') || (query.contains('payment') || query.contains('pay') || query.contains('buy'))) {
      if (query.contains('transfer') || query.contains('manual') || query.contains('bank')) {
        return localFaqs['How do I submit a manual bank transfer?'];
      }
      return localFaqs['How do I make my payment?'];
    }
    if (query.contains('bank transfer') || query.contains('manual payment') || query.contains('transfer') || query.contains('manual bank')) {
      return localFaqs['How do I submit a manual bank transfer?'];
    }
    if (query.contains('refresh') || query.contains('subscription status') || query.contains('still shows free') || query.contains('refresh status')) {
      return localFaqs['How do I force-refresh my premium status?'];
    }
    if (query.contains('unlock') || query.contains('activate') || query.contains('activation code') || query.contains('enter code')) {
      return localFaqs['How do I activate any exam?'];
    }
    if (query.contains('lock') || query.contains('bind') || query.contains('permanently lock') || query.contains('lock any exam')) {
      return localFaqs['How do I lock any exam?'];
    }
    if (query.contains('learn more') || query.contains('more setting') || query.contains('help and faq') || query.contains('about the app') || query.contains('faq page')) {
      return localFaqs['How do I learn more about the app?'];
    }

    return null;
  }

  // SECURED: Premium status is now injected per-message, not hardcoded globally.
  Future<void> sendMessage(String text, {required bool isPremium}) async {
    if (text.trim().isEmpty) return;

    _messages.insert(0, ChatMessage(text: text, isMe: true));
    await _saveCachedMessages();
    notifyListeners();

    // Start Loading/Typing state
    _isLoading = true;
    notifyListeners();

    // Check if it's a local FAQ query
    final localAnswer = _findMatchingFaqAnswer(text);
    if (localAnswer != null) {
      await Future.delayed(const Duration(milliseconds: 600)); // natural WhatsApp-like bot typing delay
      _messages.insert(0, ChatMessage(text: localAnswer, isMe: false));
      await _saveCachedMessages();
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Otherwise, treat as general AI query (requires Premium and Internet)
    if (!isPremium) {
      await Future.delayed(const Duration(milliseconds: 600));
      _messages.insert(
        0,
        ChatMessage(
          text: "This is a Premium feature. Please buy an Exam to unlock Cognita AI!",
          isMe: false,
        ),
      );
      await _saveCachedMessages();
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (!await NetworkService.instance.hasInternet()) {
      await Future.delayed(const Duration(milliseconds: 300));
      _messages.insert(
        0,
        ChatMessage(text: "You are offline. Please check your internet connection and try again.", isMe: false),
      );
      await _saveCachedMessages();
      _isLoading = false;
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

  void clearChat() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aiCacheKey);
    notifyListeners();
  }
}