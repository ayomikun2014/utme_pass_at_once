import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech Service
/// Reusable module for reading text aloud across the app
/// Usage: Exams, Classroom, Study Materials, etc.
class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _currentText;

  // Settings
  double _speechRate = 0.5; // 0.0 to 1.0 (slow to fast)
  double _volume = 1.0; // 0.0 to 1.0
  double _pitch = 1.0; // 0.5 to 2.0

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();

      await _flutterTts?.setLanguage("en-US");
      await _flutterTts?.setSpeechRate(_speechRate);
      await _flutterTts?.setVolume(_volume);
      await _flutterTts?.setPitch(_pitch);

      // Set up handlers
      _flutterTts?.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('🔊 TTS: Started speaking');
      });

      _flutterTts?.setCompletionHandler(() {
        _isSpeaking = false;
        _currentText = null;
        debugPrint('✅ TTS: Completed speaking');
      });

      _flutterTts?.setErrorHandler((msg) {
        _isSpeaking = false;
        _currentText = null;
        debugPrint('❌ TTS Error: $msg');
      });

      _isInitialized = true;
      debugPrint('✅ TTS: Initialized successfully');
    } catch (e) {
      debugPrint('❌ TTS: Failed to initialize: $e');
    }
  }

  /// Speak text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (_isSpeaking) {
        await stop();
      }

      _currentText = text;
      await _flutterTts?.speak(text);
      debugPrint(
        '🔊 TTS: Speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
      );
    } catch (e) {
      debugPrint('❌ TTS: Failed to speak: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
      _isSpeaking = false;
      _currentText = null;
      debugPrint('⏹️ TTS: Stopped');
    } catch (e) {
      debugPrint('❌ TTS: Failed to stop: $e');
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    try {
      await _flutterTts?.pause();
      debugPrint('⏸️ TTS: Paused');
    } catch (e) {
      debugPrint('❌ TTS: Failed to pause: $e');
    }
  }

  /// Resume speaking (if paused)
  Future<void> resume() async {
    try {
      // Note: Flutter TTS doesn't have native resume, so we re-speak
      if (_currentText != null) {
        await speak(_currentText!);
      }
    } catch (e) {
      debugPrint('❌ TTS: Failed to resume: $e');
    }
  }

  /// Update speech rate (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _flutterTts?.setSpeechRate(_speechRate);
    debugPrint('⚙️ TTS: Speech rate set to $_speechRate');
  }

  /// Update volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts?.setVolume(_volume);
    debugPrint('⚙️ TTS: Volume set to $_volume');
  }

  /// Update pitch (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts?.setPitch(_pitch);
    debugPrint('⚙️ TTS: Pitch set to $_pitch');
  }

  /// Read question with options
  Future<void> speakQuestion({
    required String question,
    required List<String> options,
    bool includeOptions = true,
  }) async {
    final buffer = StringBuffer();
    buffer.write('Question: ');
    buffer.write(question);

    if (includeOptions && options.isNotEmpty) {
      buffer.write('. Options are: ');
      for (int i = 0; i < options.length; i++) {
        final letter = String.fromCharCode(65 + i); // A, B, C, D
        buffer.write('Option $letter: ${options[i]}. ');
      }
    }

    await speak(buffer.toString());
  }

  /// Read solution/explanation
  Future<void> speakSolution(String solution) async {
    await speak('Solution: $solution');
  }

  /// Getters
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;

  /// Dispose (cleanup)
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
    debugPrint('🗑️ TTS: Disposed');
  }
}
