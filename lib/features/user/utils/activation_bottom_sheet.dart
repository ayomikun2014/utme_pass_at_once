import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:utme_pass_at_once/features/user/providers/simulator_provider.dart';

import '../../../core/constants/app_colors.dart';

class ActivationBottomSheet extends StatefulWidget {
  final Future<bool> Function() task;
  final VoidCallback onComplete;
  final bool isUnlockFlow;
  final bool isUpdateFlow;
  final String? errorMessage;

  const ActivationBottomSheet({
    super.key,
    required this.task,
    required this.onComplete,
    this.isUnlockFlow = false,
    this.isUpdateFlow = false,
    this.errorMessage,
  });

  @override
  State<ActivationBottomSheet> createState() => ActivationBottomSheetState();
}

class ActivationBottomSheetState extends State<ActivationBottomSheet> {
  bool _isFinished = false;
  bool _hasFailed = false;
  String? _dynamicError;
  
  // Stages: 0 = unlocking (only for unlock flow), 1 = activating/downloading
  int _stage = 0;

  int _quoteIndex = 0;
  Timer? _quoteTimer;

  static const List<String> _quotes = [
    'Preparing your personalized exam library... ✨',
    'Securing your premium access... 🔐',
    'Setting up your study environment... 📚',
    'Almost ready for success... 🚀',
    'Configuring your performance tracking... 📈',
    'Organizing your subjects... 🎯',
  ];

  static const List<String> _updateQuotes = [
    'Fetching latest questions from the cloud... 🌐',
    'Analyzing syllabus revisions... 📚',
    'Merging questions database... ⚙️',
    'Updating question answers and explanations... 💡',
    'Almost ready... success awaits! 🚀',
  ];

  @override
  void initState() {
    super.initState();
    _stage = widget.isUnlockFlow ? 0 : 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTask();
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _startQuoteTimer() {
    final quotesList = widget.isUpdateFlow ? _updateQuotes : _quotes;
    _quoteTimer?.cancel();
    _quoteTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % quotesList.length;
        });
      }
    });
  }

  Future<void> _startTask() async {
    // If we start directly in stage 1, start the timer
    if (_stage == 1) {
      _startQuoteTimer();
    }

    try {
      final result = await widget.task();

      if (mounted) {
        if (result) {
          setState(() {
            _isFinished = true;
            _stage = 1;
          });
          _quoteTimer?.cancel();
        } else {
          setState(() {
            _hasFailed = true;
            _stage = 1;
          });
          _quoteTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasFailed = true;
          _stage = 1;
          _dynamicError = e.toString().replaceAll('Exception: ', '');
        });
        _quoteTimer?.cancel();
      }
    }
  }

  // Exposed method for unlock_now.dart to manually advance to stage 1
  void advanceToActivation() {
    if (mounted) {
      setState(() {
        _stage = 1;
      });
      _startQuoteTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: _isFinished || _hasFailed,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_stage == 0) ...[
              // INITIAL UNLOCKING STAGE
              const SizedBox(
                height: 48,
                width: 48,
                child: CustomLoader(size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Unlocking Access...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Activating your voucher and permanently securing your subjects. Please wait.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ] else ...[
              // ACTIVATION IN PROGRESS STAGE
              if (_isFinished)
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56)
              else if (_hasFailed)
                const Icon(Icons.error_rounded, color: Colors.red, size: 56)
              else
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomLoader(size: 48),
                ),

              const SizedBox(height: 24),

              Text(
                _isFinished
                    ? (widget.isUpdateFlow ? 'Update Complete! 🎉' : 'Activation Complete! 🎉')
                    : _hasFailed
                        ? (widget.isUpdateFlow ? 'Update Failed' : 'Activation Failed')
                        : (widget.isUpdateFlow ? 'Updating in progress...' : 'Activation in progress...'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: _hasFailed
                      ? Colors.red
                      : isDark
                          ? Colors.white
                          : Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              if (!_isFinished && !_hasFailed) ...[
                Consumer<SimulatorProvider>(
                  builder: (context, simProvider, _) {
                    final int current = simProvider.activationProgress;
                    final int total = simProvider.activationTotal;
                    final double progressValue = total > 0 ? current / total : 0.0;
                    final int percentage = (progressValue * 100).toInt();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: total > 0 ? progressValue : null,
                            minHeight: 8,
                            color: theme.colorScheme.primary,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              total > 0 ? 'Processing...' : 'Connecting...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              total > 0 ? '$percentage%' : '0%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    widget.isUpdateFlow ? _updateQuotes[_quoteIndex] : _quotes[_quoteIndex],
                    key: ValueKey<int>(_quoteIndex),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please do not close the app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],

              if (_hasFailed) ...[
                const SizedBox(height: 12),
                Text(
                  _dynamicError ?? widget.errorMessage ?? 'An error occurred during activation. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],

              if (_isFinished) ...[
                const SizedBox(height: 12),
                 Text(
                  widget.isUpdateFlow
                      ? 'Your offline questions database has been updated successfully! All question modifications have been successfully downloaded.'
                      : 'Your offline premium package is activated! All syllabus resources, mock questions, and centers have been successfully downloaded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onComplete();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      widget.isUpdateFlow ? 'Back to Settings' : 'Okay, Let\'s Study! 🚀',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            // Extra padding at bottom for iOS home indicator
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
