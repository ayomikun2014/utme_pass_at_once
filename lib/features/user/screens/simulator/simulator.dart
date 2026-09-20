import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:utme_pass_at_once/core/services/network_service.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import 'package:utme_pass_at_once/core/text_to_speech/tts_question_btn.dart';
import 'package:utme_pass_at_once/core/text_to_speech/tts_service.dart';
import 'package:utme_pass_at_once/features/user/models/question_model.dart';
import 'package:utme_pass_at_once/features/user/services/simulator_service.dart';
import 'package:utme_pass_at_once/features/user/services/eclassroom_service.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/simulator_provider.dart';
import 'simulator_result.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:utme_pass_at_once/core/utils/rich_content_renderer.dart';
import '../../../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TTSService _ttsService = TTSService();
  final ScrollController _questionScrollController = ScrollController();

  late Map<String, dynamic> _examConfig;

  final Map<String, List<QuestionModel>> _subjectQuestions = {};
  final Map<String, Map<int, String>> _subjectAnswers = {};
  final Map<String, Set<int>> _subjectFlags = {};

  List<String> _subjects = [];
  String? _currentSubject;
  int _currentQuestionInSubject = 0;

  TabController? _tabController;

  Duration _totalTimeRemaining = Duration.zero;
  Timer? _globalTimer;
  bool _hasShown5MinWarning = false;

  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime? _examStartTime;
  DateTime? _pausedTime;
  int _activeSecondsSpent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ttsService.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && _isLoading) {
      _examConfig = Map<String, dynamic>.from(args);
      _loadQuestions();
    } else if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    _ttsService.stop();
    _tabController?.dispose();
    _questionScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
      _globalTimer?.cancel();
      _ttsService.stop();
      if (!_isLoading && !_isSubmitting && _totalTimeRemaining.inSeconds > 0) {
        NotificationService.instance.showPushNotification(
          title: 'Exam Timer Running Out!',
          body: 'Your exam is still active. The timer is running and will NOT be paused.',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsedBackground = DateTime.now().difference(_pausedTime!);
        setState(() {
          _totalTimeRemaining = _totalTimeRemaining - elapsedBackground;
        });
        _pausedTime = null;
      }
      if (!_isLoading && !_isSubmitting) {
        if (_totalTimeRemaining.inSeconds > 0) {
          _startGlobalTimer();
        } else {
          _totalTimeRemaining = Duration.zero;
          _showTimeUpDialog();
        }
      }
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    final simulatorService = SimulatorService();

    try {
      final isClassroomTest = _examConfig['isClassroomTest'] as bool? ?? false;
      final isFree = _examConfig['isFree'] as bool? ?? false;
      final examType = _examConfig['examType'] as String? ?? 'jamb';
      final subjects = List<String>.from(_examConfig['subjects'] ?? []);
      final shuffleMode = _examConfig['shuffleMode'] as bool? ?? false;

      final subjectYears = Map<String, String>.from(
        _examConfig['subjectYears'] ?? {},
      );

      final timePerSubject = _examConfig['timePerSubject'] as int? ?? 30;
      final institutionId =
          _examConfig['institutionId'] as String? ?? 'default';

      _subjectQuestions.clear();
      _subjectAnswers.clear();
      _subjectFlags.clear();

      if (isClassroomTest) {
        debugPrint('🌐 [CLASSROOM TEST] Loading classroom test questions from Firestore');
        final adminId = _examConfig['adminId'] as String;
        final testId = _examConfig['testId'] as String;
        final classroomSubject = _examConfig['subject'] as String? ?? 'General';
        
        final questions = await EClassroomService().getClassroomTestQuestions(adminId, testId);
        if (questions.isEmpty) {
          throw Exception('No questions available in this classroom test.');
        }

        _subjects = [classroomSubject];
        _subjectQuestions[classroomSubject] = questions;
        _subjectAnswers[classroomSubject] = {};
        _subjectFlags[classroomSubject] = {};
        
        final durationMinutes = int.tryParse(_examConfig['durationMinutes']?.toString() ?? '') ?? 30;
        _totalTimeRemaining = Duration(minutes: durationMinutes);
      } else if (isFree) {
        final freeSubject = subjects.isNotEmpty ? subjects.first : 'aptitude';
        final year = subjectYears[freeSubject] ?? '2014';

        debugPrint(
          '🌐 [FREE LOAD] Loading free subject $freeSubject: $examType/$institutionId/$freeSubject/$year',
        );

        // 1. Try to load from the specific cached questions first
        List<QuestionModel> questions = await simulatorService.loadCachedQuestions(
          examType: examType,
          institutionId: institutionId,
          subject: freeSubject,
          year: year,
        );

        // 2. If empty, try to load from the pre-downloaded general free cache
        if (questions.isEmpty) {
          try {
            final box = await Hive.openBox<String>('offline_questions');
            final generalData = box.get('free_${freeSubject}_$year');
            if (generalData != null && generalData.isNotEmpty) {
              final List<dynamic> decodedList = json.decode(generalData);
              questions = decodedList.map((item) {
                return QuestionModel.fromFullJson(Map<String, dynamic>.from(item));
              }).toList();
            }
          } catch (e) {
            debugPrint('⚠️ Error loading free $freeSubject from Hive cache: $e');
          }
        }

        // 3. Fallback to online fetch ONLY if we are online
        if (questions.isEmpty && NetworkService.instance.isOnline) {
          debugPrint('🌐 [FREE LOAD] Local cache empty, fetching online...');
          questions = await simulatorService.fetchQuestionsOnline(
            examType: examType,
            institutionId: institutionId,
            subject: freeSubject,
            year: year,
          );
        }

        if (questions.isEmpty) {
          throw Exception('No free $freeSubject questions available. Please check your internet connection and try again.');
        }

        _subjects = [freeSubject];
        _subjectQuestions[freeSubject] = questions;
        _subjectAnswers[freeSubject] = {};
        _subjectFlags[freeSubject] = {};
      } else if (shuffleMode) {
        debugPrint('🔧 [PREMIUM OFFLINE] Loading shuffle questions from Hive');

        final shuffleYearsRaw = _examConfig['shuffleYears'];
        final Map<String, List<String>> shuffleYears = {};

        if (shuffleYearsRaw is Map) {
          for (final entry in shuffleYearsRaw.entries) {
            shuffleYears[entry.key.toString()] = List<String>.from(entry.value);
          }
        }

        final Map<String, int> questionsPerSubjectMap = {};

        if (_examConfig['questionsPerSubjectMap'] is Map) {
          for (final entry
          in (_examConfig['questionsPerSubjectMap'] as Map).entries) {
            questionsPerSubjectMap[entry.key.toString()] = (entry.value as num)
                .toInt();
          }
        }

        _subjects = subjects;

        for (final subject in subjects) {
          final years =
              shuffleYears[subject] ?? [subjectYears[subject] ?? '2024'];

          final List<QuestionModel> allQuestions = [];

          for (final year in years) {
            final questions = await simulatorService.loadCachedQuestions(
              examType: examType,
              institutionId: institutionId,
              subject: subject,
              year: year,
            );

            if (questions.isEmpty) {
              throw Exception(
                'Offline questions missing for $subject $year. Please restore your activated package.',
              );
            }

            allQuestions.addAll(questions);
          }

          allQuestions.shuffle();

          final limit = questionsPerSubjectMap[subject];
          final finalQuestions = limit != null && limit < allQuestions.length
              ? allQuestions.take(limit).toList()
              : allQuestions;

          _subjectQuestions[subject] = finalQuestions;
          _subjectAnswers[subject] = {};
          _subjectFlags[subject] = {};
        }
      } else {
        debugPrint('🔧 [PREMIUM OFFLINE] Loading normal questions from Hive');

        _subjects = subjects;

        for (final subject in subjects) {
          final year = subjectYears[subject] ?? '2024';

          final questions = await simulatorService.loadCachedQuestions(
            examType: examType,
            institutionId: institutionId,
            subject: subject,
            year: year,
          );

          if (questions.isEmpty) {
            throw Exception(
              'Offline questions missing for $subject $year. Please restore your activated package.',
            );
          }

          _subjectQuestions[subject] = questions;
          _subjectAnswers[subject] = {};
          _subjectFlags[subject] = {};
        }
      }

      if (!isClassroomTest) {
        _totalTimeRemaining = Duration(
          minutes: timePerSubject * _subjects.length,
        );
      }

      _tabController?.dispose();
      _tabController = TabController(length: _subjects.length, vsync: this);
      _tabController!.addListener(_onTabChanged);

      _currentSubject = _subjects.isNotEmpty ? _subjects.first : null;
      _currentQuestionInSubject = 0;

      _examStartTime = DateTime.now();
      _startGlobalTimer();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading questions: $e');
      debugPrint('StackTrace: $stackTrace');

      if (!mounted) return;

      setState(() => _isLoading = false);

      CustomToast.show(
        context,
        'Failed to load questions: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );

      Navigator.pop(context);
    }
  }

  String _getWatermarkAssetPath() {
    final examType =
        _examConfig['examType']?.toString().toLowerCase() ?? 'jamb';
    String? institutionId = _examConfig['institutionId']
        ?.toString()
        .toLowerCase();

    if (institutionId != null && institutionId.contains('_')) {
      institutionId = institutionId.split('_')[0];
    }

    String normalizedExam = examType.toLowerCase().trim();

    String logoName = normalizedExam;
    if (normalizedExam == 'post_utme' &&
        institutionId != null &&
        institutionId != 'default') {
      logoName = institutionId;
    }

    return 'assets/images/$logoName.webp';
  }

  void _onTabChanged() {
    if (_tabController == null) return;
    final newSubject = _subjects[_tabController!.index];
    if (_currentSubject != newSubject) {
      setState(() {
        _currentSubject = newSubject;
        _currentQuestionInSubject = 0;
      });
      _ttsService.stop();
      
      // Reset scroll offset to 0 for the new subject
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_questionScrollController.hasClients) {
          _questionScrollController.jumpTo(0.0);
        }
      });
    }
  }

  void _startGlobalTimer() {
    _globalTimer?.cancel();
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalTimeRemaining.inSeconds > 0) {
        setState(() {
          _totalTimeRemaining =
              _totalTimeRemaining - const Duration(seconds: 1);
          _activeSecondsSpent++;
        });

        if (_totalTimeRemaining.inMinutes == 5 &&
            _totalTimeRemaining.inSeconds == 0 &&
            !_hasShown5MinWarning) {
          _hasShown5MinWarning = true;
          _show5MinuteWarning();
        }
      } else {
        _globalTimer?.cancel();
        _showTimeUpDialog();
      }
    });
  }

  void _show5MinuteWarning() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Time Warning!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timer,
                size: 48,
                color: Colors.orange.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Only 5 minutes remaining!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Please review your answers.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alarm_off, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Time Up!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'The exam time has expired. Your answers will be submitted automatically.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitExam(autoSubmit: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Submit Exam',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _answerQuestion(String answer) {
    if (_currentSubject == null) return;
    setState(() {
      _subjectAnswers[_currentSubject!]![_currentQuestionInSubject] = answer;
    });
  }

  void _toggleFlag() {
    if (_currentSubject == null) return;

    final currentQ =
    _subjectQuestions[_currentSubject!]![_currentQuestionInSubject];

    setState(() {
      if (_subjectFlags[_currentSubject!]!.contains(
        _currentQuestionInSubject,
      )) {
        _subjectFlags[_currentSubject!]!.remove(_currentQuestionInSubject);
      } else {
        _subjectFlags[_currentSubject!]!.add(_currentQuestionInSubject);
      }
    });

    final examType =
        _examConfig['examType']?.toString().toLowerCase() ?? 'jamb';
    final institutionId =
        _examConfig['institutionId']?.toString().toLowerCase() ?? 'jamb';

    // Save or remove it from the device's local bookmarks via the Provider
    context.read<SimulatorProvider>().toggleBookmark(
      currentQ,
      _currentSubject!,
      examType,
      institutionId,
    );

    // Optional: Show a quick tiny toast so the user knows it worked
    CustomToast.show(context, 
          _subjectFlags[_currentSubject!]!.contains(_currentQuestionInSubject)
              ? 'Question bookmarked to device!'
              : 'Bookmark removed.',
        );
  }

  void _navigateToQuestion(int index) {
    _ttsService.stop();
    setState(() => _currentQuestionInSubject = index);
    
    // Auto-scroll the active question button into view after layout completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_questionScrollController.hasClients) {
        final double currentOffset = _questionScrollController.offset;
        final double viewportWidth = _questionScrollController.position.viewportDimension;
        final double itemStart = index * 42.0; // button width (34) + spacing (8)
        final double itemEnd = itemStart + 34.0;
        
        double targetOffset = currentOffset;
        
        if (viewportWidth > 0) {
          // If the item is near/beyond the right edge of the viewport (or is the last visible one)
          if (itemEnd > currentOffset + viewportWidth - 42.0) {
            // Scroll so the item is at the start (left edge) of the viewport
            targetOffset = itemStart;
          } 
          // If the item is before the left edge of the viewport
          else if (itemStart < currentOffset) {
            // Scroll so the item is at the start (left edge) of the viewport
            targetOffset = itemStart;
          }
        }
        
        if (targetOffset != currentOffset) {
          _questionScrollController.animateTo(
            targetOffset.clamp(0.0, _questionScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _showCalculator() {
    showDialog(
      context: context,
      builder: (context) => const ScientificCalculatorDialog(),
    );
  }

  void _showPassageDialog(BuildContext context, Passage passage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passage.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (passage.title != null && passage.title!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        passage.title!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: RichContentRenderer(
                blocks: passage.content,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitExam({bool autoSubmit = false}) async {
    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();

    _globalTimer?.cancel();
    _ttsService.stop();

    if (!autoSubmit) {
      final totalAnswered = _subjectAnswers.values.fold(
        0,
            (sum, answers) => sum + answers.length,
      );
      final totalQuestions = _subjectQuestions.values.fold(
        0,
            (sum, list) => sum + list.length,
      );

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Submit Exam?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _submitStatColumn(
                        '$totalAnswered',
                        'Answered',
                        Colors.green,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                      _submitStatColumn(
                        '${totalQuestions - totalAnswered}',
                        'Skipped',
                        Colors.orange,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                      _submitStatColumn(
                        '$totalQuestions',
                        'Total',
                        theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You cannot return once submitted.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Submit Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        _startGlobalTimer();
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      int totalCorrect = 0;
      int totalWrong = 0;
      int totalSkipped = 0;
      final subjectScores = <String, Map<String, dynamic>>{};

      for (final subject in _subjects) {
        final questions = _subjectQuestions[subject]!;
        final answers = _subjectAnswers[subject]!;

        int correct = 0;
        int wrong = 0;
        int skipped = 0;

        for (int i = 0; i < questions.length; i++) {
          final question = questions[i];
          final userAnswer = answers[i];

          if (userAnswer == null) {
            skipped++;
          } else if (userAnswer.trim().toLowerCase() == question.correctAnswer.trim().toLowerCase()) {
            correct++;
          } else {
            wrong++;
          }
        }

        totalCorrect += correct;
        totalWrong += wrong;
        totalSkipped += skipped;

        subjectScores[subject] = {
          'score': correct,
          'total': questions.length,
          'correct': correct,
          'wrong': wrong,
          'skipped': skipped,
        };
      }

      final totalQuestions = _subjectQuestions.values.fold(
        0,
            (sum, list) => sum + list.length,
      );
      final fallbackTime = Duration(
        minutes:
        (_examConfig['timePerSubject'] as int? ?? 30) * _subjects.length,
      );
      final totalTimeTaken = _activeSecondsSpent > 0
          ? Duration(seconds: _activeSecondsSpent)
          : (_examStartTime != null
              ? DateTime.now().difference(_examStartTime!)
              : fallbackTime);

      final bool isClassroomTest = _examConfig['isClassroomTest'] as bool? ?? false;
      final bool isPractice = _examConfig['isPractice'] as bool? ?? false;

      if (isClassroomTest) {
        if (!isPractice && authProvider.currentUser != null) {
          final adminId = _examConfig['adminId'] as String;
          final testId = _examConfig['testId'] as String;
          final studentId = authProvider.currentUser!.uid;

          final Map<String, dynamic> formattedAnswers = {};
          _subjectAnswers.forEach((subj, answersMap) {
            final Map<String, String> stringKeyMap = {};
            answersMap.forEach((qIndex, selectedOption) {
              stringKeyMap[qIndex.toString()] = selectedOption;
            });
            formattedAnswers[subj] = stringKeyMap;
          });

          unawaited(
            EClassroomService().saveTestAttempt(
              adminId,
              testId,
              studentId,
              score: totalCorrect,
              totalQuestions: totalQuestions,
              timeTakenSeconds: totalTimeTaken.inSeconds,
              answers: formattedAnswers,
            ).catchError((e) {
              debugPrint('⚠️ Error in background Firestore sync for test attempt: $e');
            }),
          );
        } else if (isPractice && authProvider.currentUser != null) {
          final testId = _examConfig['testId'] as String;
          final studentId = authProvider.currentUser!.uid;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('classroom_practice_completed_${studentId}_$testId', true);
            await prefs.setInt('classroom_practice_score_${studentId}_$testId', totalCorrect);
            await prefs.setInt('classroom_practice_total_${studentId}_$testId', totalQuestions);

            final Map<String, dynamic> formattedAnswers = {};
            _subjectAnswers.forEach((subj, answersMap) {
              final Map<String, String> stringKeyMap = {};
              answersMap.forEach((qIndex, selectedOption) {
                stringKeyMap[qIndex.toString()] = selectedOption;
              });
              formattedAnswers[subj] = stringKeyMap;
            });
            await prefs.setString('classroom_practice_answers_${studentId}_$testId', jsonEncode(formattedAnswers));

            debugPrint('💾 [CLASSROOM TEST] Saved local practice completion, score ($totalCorrect/$totalQuestions), and answers for test: $testId');
          } catch (e) {
            debugPrint('⚠️ Error saving local practice completion status: $e');
          }
        }
      } else {
        await simProvider.saveExamResult(
          authProvider,
          examConfig: _examConfig,
          subjectQuestions: _subjectQuestions,
          subjectAnswers: _subjectAnswers,
          results: {
            'score': totalCorrect,
            'correctAnswers': totalCorrect,
            'wrongAnswers': totalWrong,
            'skippedAnswers': totalSkipped,
            'subjectScores': subjectScores,
          },
          totalQuestions: totalQuestions,
          timeTaken: totalTimeTaken,
        );
      }

      // --- AUTOMATED NOTIFICATIONS ---
      if (authProvider.currentUser != null) {
        final uid = authProvider.currentUser!.uid;

        final percentStr = totalQuestions > 0
            ? (totalCorrect / totalQuestions * 100).toStringAsFixed(0)
            : '0';

        // 1. Exam Finished Notification
        NotificationService.instance.createInAppNotification(
          uid: uid,
          title: 'Exam Completed! 📝',
          body:
          'You scored $percentStr% ($totalCorrect/$totalQuestions) in ${totalTimeTaken.inMinutes} minutes.',
          type: 'exam_finished',
        );

        // 2. High Score Notification (if >= 75%)
        if (totalQuestions > 0 && (totalCorrect / totalQuestions) >= 0.75) {
          NotificationService.instance.createInAppNotification(
            uid: uid,
            title: 'Excellent Performance! 🌟',
            body:
            'You scored ${(totalCorrect / totalQuestions * 100).toStringAsFixed(0)}% on your recent test. Keep up the great work!',
            type: 'high_score',
          );
        }
      }
      // -----------------------------

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SimulatorResultScreen(
              results: {
                'score': totalCorrect,
                'correctAnswers': totalCorrect,
                'wrongAnswers': totalWrong,
                'skippedAnswers': totalSkipped,
                'subjectScores': subjectScores,
              },
              totalQuestions: totalQuestions,
              timeTaken: totalTimeTaken,
              subjectQuestions: _subjectQuestions,
              subjectAnswers: _subjectAnswers,
              examConfig: _examConfig,
              fromExam: true,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        CustomToast.show(context, 'Error submitting exam: $e', isError: true);
      }
    }
  }

  Widget _submitStatColumn(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CustomLoader()));
    }

    if (_currentSubject == null ||
        _subjectQuestions[_currentSubject!]!.isEmpty) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            const CustomAppBar(title: 'Error'),
            SliverFillRemaining(
              child: Center(child: Text('No questions available')),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await _confirmExitExam();

        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Watermark Background
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.1,
                  child: Image.asset(
                    _getWatermarkAssetPath(),
                    width: MediaQuery.of(context).size.width * 0.7,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // Foreground Content
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(theme, isDark),
                  _buildSubjectTabs(theme, isDark),
                  Expanded(
                    child: _isSubmitting
                        ? const Center(child: CustomLoader())
                        : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _subjects.map((subject) {
                        return _buildSubjectView(subject);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<bool> _confirmExitExam() async {
    _globalTimer?.cancel();
    _ttsService.stop();

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.exit_to_app,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Exit Exam?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your current answers will be lost if you go back now. Are you sure you want to exit this exam?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Exam'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      return true;
    }

    if (mounted && !_isSubmitting) {
      _startGlobalTimer();
    }

    return false;
  }

  Widget _buildTopBar(ThemeData theme, bool isDark) {
    final isUrgent = _totalTimeRemaining.inMinutes < 5;

    final examTitle =
    _examConfig['examType']?.toString().toLowerCase() == 'jamb'
        ? 'JAMB UTME'
        : _examConfig['examType']?.toString().toUpperCase() ?? 'JAMB UTME';

    final institutionName =
        _examConfig['institutionName']?.toString() ?? 'Examination Center';

    final sectionName = _examConfig['sectionName']?.toString().trim();

    final subtitle = sectionName != null && sectionName.isNotEmpty
        ? '$institutionName • $sectionName'
        : institutionName;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.primary,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final shouldExit = await _confirmExitExam();
              if (!mounted) return;
              if (shouldExit) {
                navigator.pop();
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: isDark ? Colors.white70 : Colors.white,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.white.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Timer Widget
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red.withValues(alpha: 0.15)
                  : (isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isUrgent
                    ? Colors.redAccent
                    : (isDark ? AppColors.primary.withValues(alpha: 0.3) : Colors.white30),
                width: 1.5,
              ),
              boxShadow: isUrgent
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUrgent
                      ? Icons.error_outline_rounded
                      : Icons.alarm_rounded,
                  color: isUrgent ? Colors.red : (isDark ? AppColors.primary : Colors.white),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_totalTimeRemaining),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: isUrgent ? Colors.red : (isDark ? AppColors.primary : Colors.white),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTabs(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _tabController!,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.4) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_subjects.length, (index) {
                final subject = _subjects[index];
                final isSelected = _tabController!.index == index;

                final answered = _subjectAnswers[subject]?.length ?? 0;
                final total = _subjectQuestions[subject]?.length ?? 0;
                final isComplete = answered == total && total > 0;

                return GestureDetector(
                  onTap: () {
                    _tabController!.animateTo(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isComplete
                              ? Colors.green.withValues(alpha: 0.08)
                              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isComplete
                                ? Colors.green.withValues(alpha: 0.5)
                                : (isDark ? AppColors.dividerDark : Colors.grey.shade300)),
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subject.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isComplete
                                    ? Colors.green
                                    : (isDark ? Colors.white70 : Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : (isComplete
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '$answered/$total',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isComplete
                                      ? Colors.green
                                      : (isDark ? Colors.white60 : Colors.grey.shade700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectView(String subject) {
    final questions = _subjectQuestions[subject]!;
    final safeIndex = _currentQuestionInSubject < questions.length
        ? _currentQuestionInSubject
        : 0;
    final currentQuestion = questions[safeIndex];
    final answers = _subjectAnswers[subject]!;
    final flags = _subjectFlags[subject]!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark; // FIXED: Added isDark check
    final isFlagged = flags.contains(safeIndex);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q ${safeIndex + 1} / ${questions.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  currentQuestion.year,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _showCalculator,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.calculate_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _toggleFlag,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isFlagged
                            ? Colors.red.withValues(alpha: 0.08)
                            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFlagged
                              ? Colors.red.withValues(alpha: 0.25)
                              : (isDark ? AppColors.dividerDark : Colors.grey.shade300),
                        ),
                      ),
                      child: Icon(
                        isFlagged ? Icons.flag : Icons.flag_outlined,
                        size: 16,
                        color: isFlagged
                            ? Colors.red
                            : (isDark ? Colors.white60 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TTSQuestionButton(
                    question: extractPlainText(currentQuestion.content),
                    options: currentQuestion.options
                        .map((o) => o.plainText)
                        .toList(),
                    ttsService: _ttsService,
                    includeOptions: true,
                  ),
                  const SizedBox(width: 8),
                  // Premium inline submit button
                  GestureDetector(
                    onTap: () => _submitExam(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimationLimiter(
            key: ValueKey('$_currentSubject-$safeIndex'),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentQuestion.passage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextButton.icon(
                        onPressed: () => _showPassageDialog(context, currentQuestion.passage!),
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(
                          currentQuestion.passage!.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: isDark 
                              ? AppColors.primary.withValues(alpha: 0.15) 
                              : AppColors.primary.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (currentQuestion.instruction != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? AppColors.primary.withValues(alpha: 0.15) 
                              : AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentQuestion.instruction!.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppColors.primaryDark : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichContentRenderer(
                              blocks: currentQuestion.instruction!.content,
                              textStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  AnimationConfiguration.staggeredList(
                    position: 0,
                    duration: const Duration(milliseconds: 400),
                    child: SlideAnimation(
                      verticalOffset: 20.0,
                      child: FadeInAnimation(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? AppColors.surfaceDark.withValues(alpha: 0.5) 
                                : AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark 
                                  ? AppColors.dividerDark 
                                  : AppColors.primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: RichContentRenderer(
                            blocks: currentQuestion.content,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...List.generate(currentQuestion.options.length, (index) {
                    final option = currentQuestion.options[index].key;
                    final isSelected = answers[safeIndex] == option;
                    final optionBlocks = currentQuestion.options[index].content;

                    return AnimationConfiguration.staggeredList(
                      position: index + 2,
                      duration: const Duration(milliseconds: 300),
                      child: SlideAnimation(
                        verticalOffset: 30.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GestureDetector(
                              onTap: () => _answerQuestion(option),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.6)
                                        : (isDark ? AppColors.dividerDark : Colors.grey.shade200),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isSelected
                                      ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark ? Colors.white30 : Colors.grey.shade400),
                                          width: 2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: isSelected
                                            ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                            : Text(
                                          option,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichContentRenderer(
                                        blocks: optionBlocks,
                                        textStyle: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? (isDark ? Colors.white : AppColors.primary)
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        _buildQuestionGrid(theme, isDark, questions, answers, flags, safeIndex),
        _buildNavButtons(theme, isDark, questions, safeIndex),
      ],
    );
  }

  Widget _buildQuestionGrid(
    ThemeData theme,
    bool isDark,
    List<QuestionModel> questions,
    Map<int, String> answers,
    Set<int> flags,
    int safeIndex,
  ) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        controller: _questionScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(questions.length, (index) {
            final isAnswered = answers.containsKey(index);
            final isCurrent = index == safeIndex;
            final isFlagged = flags.contains(index);

            return Padding(
              padding: EdgeInsets.only(
                right: index == questions.length - 1 ? 0.0 : 8.0,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToQuestion(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: isCurrent
                            ? const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF6B4EE6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: !isCurrent
                            ? (isAnswered
                                ? Colors.green.withValues(alpha: 0.1)
                                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white))
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent
                              ? Colors.transparent
                              : (isAnswered
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : (isDark ? AppColors.dividerDark : Colors.grey.shade300)),
                          width: isCurrent ? 0 : 1.2,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : (isAnswered
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: isCurrent
                                ? Colors.white
                                : (isAnswered
                                    ? Colors.green
                                    : (isDark ? Colors.white60 : Colors.grey.shade700)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isFlagged)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavButtons(
    ThemeData theme,
    bool isDark,
    List<QuestionModel> questions,
    int safeIndex,
  ) {
    final isFirstQ = safeIndex == 0;
    final isLastQ = safeIndex == questions.length - 1;
    final isLastSubject = _tabController!.index == _subjects.length - 1;

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double safeBottom = bottomPadding > 0 ? bottomPadding + 12.0 : 26.0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, safeBottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isFirstQ)
            Expanded(
              child: _navButton(
                theme,
                isDark,
                icon: Icons.chevron_left_rounded,
                label: 'Previous',
                filled: false,
                onTap: () => _navigateToQuestion(safeIndex - 1),
              ),
            ),
          if (!isFirstQ) const SizedBox(width: 12),
          if (!isLastQ)
            Expanded(
              child: _navButton(
                theme,
                isDark,
                icon: Icons.chevron_right_rounded,
                label: 'Next',
                filled: true,
                color: AppColors.primary,
                onTap: () => _navigateToQuestion(safeIndex + 1),
              ),
            ),
          if (isLastQ)
            Expanded(
              child: _navButton(
                theme,
                isDark,
                icon: isLastSubject
                    ? Icons.check_circle_outline_rounded
                    : Icons.chevron_right_rounded,
                label: isLastSubject ? 'Submit Exam' : 'Next Subject',
                filled: true,
                color: isLastSubject ? Colors.green : AppColors.primary,
                onTap: () {
                  if (isLastSubject) {
                    _submitExam();
                  } else {
                    _tabController!.animateTo(_tabController!.index + 1);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _navButton(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [
                    buttonColor,
                    buttonColor == Colors.green 
                        ? const Color(0xFF2E7D32) 
                        : const Color(0xFF6B4EE6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: filled ? null : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: filled
              ? null
              : Border.all(
                  color: isDark ? AppColors.dividerDark : AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon == Icons.chevron_left_rounded) ...[
              Icon(
                icon,
                size: 20,
                color: filled ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: filled ? Colors.white : AppColors.primary,
              ),
            ),
            if (icon != Icons.chevron_left_rounded) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 20,
                color: filled ? Colors.white : AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

// =====================================================================
// NEW: CUSTOM SCIENTIFIC CALCULATOR BOTTOM SHEET / DIALOG
// =====================================================================

class ScientificCalculatorDialog extends StatefulWidget {
  const ScientificCalculatorDialog({super.key});

  @override
  State<ScientificCalculatorDialog> createState() =>
      _ScientificCalculatorDialogState();
}

class _ScientificCalculatorDialogState
    extends State<ScientificCalculatorDialog> {
  String _expression = '';
  String _result = '';

  final List<String> _buttons = [
    'C',
    'DEL',
    '(',
    ')',
    'sin',
    'cos',
    'tan',
    'log',
    'sqrt',
    '^',
    '%',
    '÷',
    '7',
    '8',
    '9',
    'x',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '+',
    '0',
    '.',
    'pi',
    '=',
  ];

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _expression = '';
        _result = '';
      } else if (buttonText == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (buttonText == '=') {
        _evaluateExpression();
      } else {
        _expression += buttonText;
      }
    });
  }

  void _evaluateExpression() {
    String finalExpression = _expression;
    // Replace custom display operators with real math operators
    finalExpression = finalExpression.replaceAll('x', '*');
    finalExpression = finalExpression.replaceAll('÷', '/');
    finalExpression = finalExpression.replaceAll('pi', '3.141592653589793');

    try {
      // Use the new modern GrammarParser instead of the deprecated Parser
      GrammarParser p = GrammarParser();
      Expression exp = p.parse(finalExpression);
      ContextModel cm = ContextModel();

      // Tell Dart to safely ignore the deprecation warning for the evaluate method
      // ignore: deprecated_member_use
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      // Clean up the decimal if it's a whole number
      _result = eval.toString();
      if (_result.endsWith('.0')) {
        _result = _result.substring(0, _result.length - 2);
      }
    } catch (e) {
      _result = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top handle to close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scientific Calculator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Screen Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? '0' : _expression,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _result,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Button Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio:
                  1.3,
                ),
                itemCount: _buttons.length,
                itemBuilder: (context, index) {
                  final btnText = _buttons[index];

                  // Color Logic
                  Color btnColor = isDark ? Colors.grey[800]! : Colors.white;
                  Color textColor = isDark ? Colors.white : Colors.black87;

                  if (btnText == 'C' || btnText == 'DEL') {
                    btnColor = Colors.red.shade100;
                    textColor = Colors.red.shade900;
                  } else if (['+', '-', 'x', '÷', '='].contains(btnText)) {
                    btnColor = theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    );
                    textColor = theme.colorScheme.primary;
                  } else if ([
                    'sin',
                    'cos',
                    'tan',
                    'log',
                    'sqrt',
                    '^',
                    '%',
                    'pi',
                    '(',
                    ')',
                  ].contains(btnText)) {
                    btnColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
                    textColor = isDark ? Colors.white70 : Colors.black54;
                  }

                  if (btnText == '=') {
                    btnColor = theme.colorScheme.primary;
                    textColor = Colors.white;
                  }

                  return InkWell(
                    onTap: () => _onButtonPressed(btnText),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          btnText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}