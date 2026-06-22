import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/eclassroom_models.dart';
import '../../models/question_model.dart';
import '../../services/eclassroom_service.dart';
import '../simulator/simulator.dart';
import '../simulator/simulator_review.dart';

class TestListScreen extends StatefulWidget {
  final String adminId;
  final String subject;
  const TestListScreen({super.key, required this.adminId, required this.subject});

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> with SingleTickerProviderStateMixin {
  final EClassroomService _classroomService = EClassroomService();
  TabController? _tabController;
  Timer? _countdownTimer;
  
  bool _isLoading = true;
  String? _errorMessage;
  
  List<ClassroomTest> _allTests = [];
  Map<String, Map<String, dynamic>> _studentAttempts = {}; // testId -> attemptData
  Map<String, Map<String, dynamic>> _practiceAttempts = {}; // testId -> practiceAttemptData

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    
    // Start periodic countdown timer updating UI every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.uid ?? '';
      
      // 1. Fetch all classroom tests
      final tests = await _classroomService.getTests(widget.adminId);
      
      // 2. Fetch student attempts in parallel
      final Map<String, Map<String, dynamic>> attempts = {};
      final List<Future<void>> attemptFutures = tests.map((test) async {
        final attempt = await _classroomService.getTestAttempt(widget.adminId, test.id, studentId);
        if (attempt != null) {
          attempts[test.id] = attempt;
        }
      }).toList();

      await Future.wait(attemptFutures);

      // 3. Fetch local practice attempts
      final Map<String, Map<String, dynamic>> localPracticeAttempts = {};
      final prefs = await SharedPreferences.getInstance();
      for (final test in tests) {
        final hasPractice = prefs.getBool('classroom_practice_completed_${studentId}_${test.id}') ?? false;
        if (hasPractice) {
          final score = prefs.getInt('classroom_practice_score_${studentId}_${test.id}') ?? 0;
          final total = prefs.getInt('classroom_practice_total_${studentId}_${test.id}') ?? 0;
          final answersStr = prefs.getString('classroom_practice_answers_${studentId}_${test.id}');
          Map<String, dynamic> answersMap = {};
          if (answersStr != null) {
            try {
              answersMap = jsonDecode(answersStr);
            } catch (e) {
              debugPrint('Failed to decode local practice answers: $e');
            }
          }
          localPracticeAttempts[test.id] = {
            'score': score,
            'totalQuestions': total,
            'answers': answersMap,
            'isLocalPractice': true,
          };
        }
      }

      if (mounted) {
        setState(() {
          _allTests = tests;
          _studentAttempts = attempts;
          _practiceAttempts = localPracticeAttempts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // Helper: Generates beautiful live countdown string
  String _getCountdownText(DateTime deadline) {
    final nowWAT = DateTime.now().toUtc().add(const Duration(hours: 1));
    final deadlineWAT = deadline.toUtc().add(const Duration(hours: 1));
    final difference = deadlineWAT.difference(nowWAT);
    
    if (difference.isNegative) {
      return 'Expired';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h ${difference.inMinutes % 60}m remaining';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ${difference.inSeconds % 60}s remaining';
    }
    return '${difference.inMinutes}m ${difference.inSeconds % 60}s remaining';
  }

  // Checks if deadline has expired
  bool _isDeadlineExpired(DateTime deadline) {
    final nowWAT = DateTime.now().toUtc().add(const Duration(hours: 1));
    final deadlineWAT = deadline.toUtc().add(const Duration(hours: 1));
    return deadlineWAT.isBefore(nowWAT);
  }

  // Prepares questions and attempts answers maps and launches SimulatorReviewScreen
  Future<void> _launchReviewScreen(ClassroomTest test) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CustomLoader(),
                ),
                const SizedBox(height: 24),
                Text(
                  "Loading Review Details...",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait while we prepare review questions.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.uid ?? '';

      // Load questions and attempt in parallel
      final results = await Future.wait([
        _classroomService.getClassroomTestQuestions(widget.adminId, test.id),
        _classroomService.getTestAttempt(widget.adminId, test.id, studentId),
      ]);

      final questions = results[0] as List;
      final attemptData = (results[1] as Map<String, dynamic>?) ?? _practiceAttempts[test.id];

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (questions.isEmpty) {
        if (mounted) {
          CustomToast.show(context, 'No questions found for this test.');
        }
        return;
      }

      // Reconstruct student answers map remapping string Firestore keys to int
      final Map<String, Map<int, String>> subjectAnswers = {};
      if (attemptData != null && attemptData['answers'] != null) {
        final rawAnswers = attemptData['answers'] as Map<String, dynamic>;
        
        final String currentSubject = test.subject;
        final String actualAnswersKey = rawAnswers.keys.firstWhere(
          (k) => k == currentSubject,
          orElse: () => rawAnswers.keys.isNotEmpty ? rawAnswers.keys.first : currentSubject,
        );

        final ansMap = rawAnswers[actualAnswersKey];
        if (ansMap is Map) {
          final Map<int, String> parsedAns = {};
          ansMap.forEach((key, val) {
            final intIdx = int.tryParse(key.toString());
            if (intIdx != null) {
              parsedAns[intIdx] = val.toString();
            }
          });
          subjectAnswers[currentSubject] = parsedAns;
        }
      }

      final Map<String, List<QuestionModel>> subjectQuestions = {
        test.subject: List<QuestionModel>.from(questions),
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimulatorReviewScreen(
              subjectQuestions: subjectQuestions,
              subjectAnswers: subjectAnswers,
              examConfig: {
                'examType': 'CLASSROOM',
                'sectionName': test.title,
                'subject': test.subject,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        CustomToast.show(context, 'Failed to load review: $e');
      }
    }
  }

  // Launches CBT Simulator
  void _startExam(ClassroomTest test, {required bool isPractice}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimulatorScreen(),
        settings: RouteSettings(
          arguments: <String, dynamic>{
            'isClassroomTest': true,
            'isPractice': isPractice,
            'adminId': widget.adminId,
            'testId': test.id,
            'subject': test.subject,
            'durationMinutes': test.durationMinutes,
            'deadline': test.deadline.toIso8601String(),
            'title': test.title,
            'examType': 'CLASSROOM',
            'shuffleMode': false,
            'subjects': [test.subject],
          },
        ),
      ),
    ).then((_) => _loadData()); // Refresh attempts list when student exits or finishes
  }

  // Opens a custom premium session setup bottom sheet details
  void _showTestSetupBottomSheet(ClassroomTest test) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 45,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title and Subject Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            test.subject,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Detail cards
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCard(
                      context,
                      Icons.hourglass_top_rounded,
                      'Duration',
                      '${test.durationMinutes} mins',
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDetailCard(
                      context,
                      Icons.quiz_rounded,
                      'Questions',
                      '${test.totalQuestions} Qs',
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Deadline: ${DateFormat('MMM dd, yyyy - hh:mm a').format(test.deadline.toUtc().add(const Duration(hours: 1)))} (WAT)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Instructions Box
              Text(
                'Instructions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  test.instructions,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _startExam(test, isPractice: false);
                  },
                  child: const Text(
                    'Start Attempt',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, IconData icon, String title, String val, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Opens a beautiful Practice-First reminder dialogue for missed tests
  void _showPracticeReminderDialog(ClassroomTest test) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Practice Required',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Since you did not attempt this exam during the active window, you must complete a Practice Mode run first before unlocking the full question solutions and reviews.',
            style: TextStyle(height: 1.4, color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _startExam(test, isPractice: true);
              },
              child: const Text('Start Practice', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter Active and Completed/Expired tests by subject
    final activeTests = _allTests.where((test) {
      if (test.subject.trim().toLowerCase() != widget.subject.trim().toLowerCase()) return false;
      final attempted = _studentAttempts.containsKey(test.id);
      final expired = _isDeadlineExpired(test.deadline);
      return !attempted && !expired;
    }).toList();

    final completedTests = _allTests.where((test) {
      if (test.subject.trim().toLowerCase() != widget.subject.trim().toLowerCase()) return false;
      final attempted = _studentAttempts.containsKey(test.id);
      final expired = _isDeadlineExpired(test.deadline);
      return attempted || expired;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text(
                    '${widget.subject} Tests',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Active Tests'),
                      Tab(text: 'Completed & Past'),
                    ],
                  ),
                ),
              ];
            },
            body: _isLoading
                ? const Center(child: CustomLoader())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to load classroom tests',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                onPressed: _loadData,
                                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActiveTestsList(activeTests, isDark),
                          _buildCompletedTestsList(completedTests, isDark),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // Builds the list of available/active classroom tests
  Widget _buildActiveTestsList(List<ClassroomTest> tests, bool isDark) {
    if (tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 70, color: isDark ? Colors.white30 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No active tests currently',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back later for newly assigned tests.',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        final countdownText = _getCountdownText(test.deadline);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject and countdown timer row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          test.subject.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Text(
                          countdownText,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Test Title
                Text(
                  test.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deadline: ${DateFormat('MMM dd, yyyy - hh:mm a').format(test.deadline.toUtc().add(const Duration(hours: 1)))} (WAT)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stats row + action
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${test.durationMinutes} mins', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Icon(Icons.format_list_numbered_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${test.totalQuestions} Questions', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _showTestSetupBottomSheet(test),
                      child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Builds the list of completed and past/missed classroom tests
  Widget _buildCompletedTestsList(List<ClassroomTest> tests, bool isDark) {
    if (tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu_outlined, size: 70, color: isDark ? Colors.white30 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No completed or past tests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        final attempt = _studentAttempts[test.id];
        final hasAttempted = attempt != null;
        final expired = _isDeadlineExpired(test.deadline);
        
        // Detailed badging logic
        Color statusColor;
        String statusText;
        IconData statusIcon;
        Widget scoreTextWidget = const SizedBox.shrink();

        if (hasAttempted) {
          statusColor = Colors.green;
          statusText = 'Completed';
          statusIcon = Icons.check_circle_outline_rounded;
          
          final scoreVal = int.tryParse(attempt['score']?.toString() ?? '0') ?? 0;
          final totalQuestions = int.tryParse(attempt['totalQuestions']?.toString() ?? '') ?? 
                                 (attempt['totalQuestions'] as num?)?.toInt() ?? 
                                 test.totalQuestions;
          final double percentage = totalQuestions > 0 ? (scoreVal / totalQuestions * 100) : 0.0;
          
          scoreTextWidget = Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Score: $scoreVal/$totalQuestions (${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          );
        } else {
          statusColor = Colors.red;
          statusText = 'Missed - Deadline Expired';
          statusIcon = Icons.error_outline_rounded;
        }

        // Determine if review and practice is currently locked
        // Lock applies IF the user has attempted the test but the deadline has NOT expired yet
        final bool isLocked = !expired && hasAttempted;
        
        final deadlineWAT = test.deadline.toUtc().add(const Duration(hours: 1));
        final deadlineStr = DateFormat('MMM dd, yyyy - hh:mm a').format(deadlineWAT);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge header
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: test.subject == 'General'
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.grey.shade500.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          test.subject.toUpperCase(),
                          style: TextStyle(
                            color: test.subject == 'General' ? AppColors.primary : Colors.grey,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title & score info
                Text(
                  test.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                scoreTextWidget,
                const SizedBox(height: 12),

                // Deadline subtitle info
                Text(
                  'Deadline: $deadlineStr',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),

                // Action area
                if (isLocked) ...[
                  // Elegant Warning Message locking review/redo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Practice and Answer Review will unlock once the test deadline has expired.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Premium Action Buttons: Review & Redo (Practice)
                  Row(
                    children: [
                      // Review button
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                          label: const Text('Review Answers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (!hasAttempted && !_practiceAttempts.containsKey(test.id)) {
                              // Rule: Missed test requires a Practice Run before viewing reviews
                              _showPracticeReminderDialog(test);
                            } else {
                              _launchReviewScreen(test);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Practice mode redo button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                          label: const Text('Practice Redo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _startExam(test, isPractice: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
