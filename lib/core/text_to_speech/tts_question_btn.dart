import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/text_to_speech/tts_service.dart';

class TTSQuestionButton extends StatefulWidget {
  final String question;
  final List<String> options;
  final TTSService ttsService;
  final bool includeOptions;

  const TTSQuestionButton({
    super.key,
    required this.question,
    required this.options,
    required this.ttsService,
    this.includeOptions = true,
  });

  @override
  State<TTSQuestionButton> createState() => _TTSQuestionButtonState();
}

class _TTSQuestionButtonState extends State<TTSQuestionButton> {
  bool _isSpeaking = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isSpeaking ? Icons.stop_circle : Icons.volume_up,
        color: _isSpeaking ? Colors.red : null,
      ),
      tooltip: _isSpeaking ? 'Stop reading' : 'Read question',
      onPressed: () async {
        if (_isSpeaking) {
          await widget.ttsService.stop();
          setState(() => _isSpeaking = false);
        } else {
          setState(() => _isSpeaking = true);
          await widget.ttsService.speakQuestion(
            question: widget.question,
            options: widget.options,
            includeOptions: widget.includeOptions,
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && !widget.ttsService.isSpeaking) {
            setState(() => _isSpeaking = false);
          }
        }
      },
    );
  }
}
