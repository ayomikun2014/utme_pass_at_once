import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/features/user/models/question_model.dart';
import 'package:utme_pass_at_once/core/utils/rich_content_renderer.dart';

/// Exam Review Screen
/// Shows all questions with user answers, correct solutions, and diagrams
class SimulatorReviewScreen extends StatefulWidget {
  final Map<String, List<QuestionModel>> subjectQuestions;
  final Map<String, Map<int, String>> subjectAnswers;
  final Map<String, dynamic> examConfig;

  const SimulatorReviewScreen({
    super.key,
    required this.subjectQuestions,
    required this.subjectAnswers,
    required this.examConfig,
  });

  @override
  State<SimulatorReviewScreen> createState() => _SimulatorReviewScreenState();
}

class _SimulatorReviewScreenState extends State<SimulatorReviewScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _subjects = [];
  String? _currentSubject;
  int _currentQuestionIndex = 0;

  // Filter options: all, correct, wrong, skipped
  String _filter = 'all';

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
                        color: theme.colorScheme.primary,
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

  @override
  void initState() {
    super.initState();

    _subjects = widget.subjectQuestions.keys.toList();

    if (_subjects.isNotEmpty) {
      _currentSubject = _subjects.first;

      _tabController = TabController(
        length: _subjects.length,
        vsync: this,
      );

      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) {
          setState(() {
            _currentSubject = _subjects[_tabController!.index];
            _currentQuestionIndex = 0;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String _examBadgeText() {
    final examType =
        widget.examConfig['examType']?.toString().toUpperCase() ?? 'REVIEW';

    final sectionName = widget.examConfig['sectionName']?.toString().trim();

    if (sectionName != null && sectionName.isNotEmpty) {
      return '$examType • $sectionName';
    }

    return examType;
  }

  List<int> _getFilteredQuestionIndicesForSubject(String subject) {
    final questions = widget.subjectQuestions[subject] ?? [];
    final answers = widget.subjectAnswers[subject] ?? {};

    final List<int> indices = [];

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final userAnswer = answers[i];

      switch (_filter) {
        case 'all':
          indices.add(i);
          break;

        case 'correct':
          if (userAnswer != null && userAnswer.trim().toLowerCase() == question.correctAnswer.trim().toLowerCase()) {
            indices.add(i);
          }
          break;

        case 'wrong':
          if (userAnswer != null && userAnswer.trim().toLowerCase() != question.correctAnswer.trim().toLowerCase()) {
            indices.add(i);
          }
          break;

        case 'skipped':
          if (userAnswer == null) {
            indices.add(i);
          }
          break;
      }
    }

    return indices;
  }

  List<int> _getCurrentFilteredQuestionIndices() {
    if (_currentSubject == null) return [];
    return _getFilteredQuestionIndicesForSubject(_currentSubject!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_currentSubject == null ||
        widget.subjectQuestions[_currentSubject!] == null ||
        widget.subjectQuestions[_currentSubject!]!.isEmpty ||
        _tabController == null) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No questions to review',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredIndices = _getCurrentFilteredQuestionIndices();

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          _buildSubjectTabs(theme),
          _buildFilterChips(theme),

          if (filteredIndices.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.05,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${_filter.toUpperCase()} questions in ${_currentSubject?.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: _subjects.map((subject) {
                  return _buildSubjectReview(subject);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: const Text(
        'Review Answers',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _examBadgeText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectTabs(ThemeData theme) {
    return AnimatedBuilder(
      animation: _tabController!,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_subjects.length, (index) {
                final subject = _subjects[index];
                final isSelected = _tabController!.index == index;
                final questions = widget.subjectQuestions[subject] ?? [];
                final answers = widget.subjectAnswers[subject] ?? {};

                int correct = 0;
                int wrong = 0;

                for (int i = 0; i < questions.length; i++) {
                  final ans = answers[i];
                  if (ans != null && ans.trim().toLowerCase() == questions[i].correctAnswer.trim().toLowerCase()) {
                    correct++;
                  } else if (ans != null) {
                    wrong++;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    _tabController!.animateTo(index);
                    setState(() {
                      _currentSubject = subject;
                      _currentQuestionIndex = 0;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Text(
                          subject.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildScoreBadge(correct, Colors.green, isSelected),
                        const SizedBox(width: 4),
                        _buildScoreBadge(
                          wrong,
                          Colors.red.shade400,
                          isSelected,
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

  Widget _buildScoreBadge(int count, Color color, bool isTabSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isTabSelected
            ? Colors.white.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isTabSelected ? Colors.white : color,
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              theme,
              'All',
              'all',
              Icons.list_rounded,
              theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              theme,
              'Correct',
              'correct',
              Icons.check_circle_rounded,
              Colors.green,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              theme,
              'Wrong',
              'wrong',
              Icons.cancel_rounded,
              Colors.red.shade500,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              theme,
              'Skipped',
              'skipped',
              Icons.remove_circle_outline_rounded,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      ThemeData theme,
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    final isSelected = _filter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
          _currentQuestionIndex = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectReview(String subject) {
    final questions = widget.subjectQuestions[subject] ?? [];
    final answers = widget.subjectAnswers[subject] ?? {};
    final filteredIndices = _getFilteredQuestionIndicesForSubject(subject);
    final theme = Theme.of(context);

    if (filteredIndices.isEmpty) {
      return const SizedBox();
    }

    final safeCurrentIndex = _currentQuestionIndex >= filteredIndices.length
        ? filteredIndices.length - 1
        : _currentQuestionIndex;

    final actualIndex = filteredIndices[safeCurrentIndex];
    final question = questions[actualIndex];
    final userAnswer = answers[actualIndex];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q ${safeCurrentIndex + 1} / ${filteredIndices.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Original #${actualIndex + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildQuestionReviewContent(
              theme,
              question,
              userAnswer,
              actualIndex,
            ),
          ),
        ),
        _buildNavigationBar(theme, filteredIndices),
      ],
    );
  }

  Widget _buildNavigationBar(ThemeData theme, List<int> filteredIndices) {
    final isFirst = _currentQuestionIndex == 0;
    final isLast = _currentQuestionIndex >= filteredIndices.length - 1;

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double safeBottom = bottomPadding > 0 ? bottomPadding + 12.0 : 26.0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, safeBottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              child: _navButton(
                theme,
                icon: Icons.arrow_back_rounded,
                label: 'Previous',
                filled: false,
                onTap: () {
                  setState(() {
                    _currentQuestionIndex--;
                  });
                },
              ),
            ),
          if (!isFirst && !isLast) const SizedBox(width: 12),
          if (!isLast)
            Expanded(
              child: _navButton(
                theme,
                icon: Icons.arrow_forward_rounded,
                label: 'Next',
                filled: true,
                onTap: () {
                  setState(() {
                    _currentQuestionIndex++;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _navButton(
      ThemeData theme, {
        required IconData icon,
        required String label,
        required bool filled,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.85),
            ],
          )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          boxShadow: filled
              ? [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: filled ? Colors.white : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionReviewContent(
      ThemeData theme,
      QuestionModel question,
      String? userAnswer,
      int actualIndex,
      ) {
    final isDark = theme.brightness == Brightness.dark;

    final isCorrect = userAnswer != null && userAnswer.trim().toLowerCase() == question.correctAnswer.trim().toLowerCase();
    final isSkipped = userAnswer == null;
    final correctAnswer = question.correctAnswer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Q${actualIndex + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${question.subjectName.toUpperCase()} • ${question.year}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ),
                  _buildStatusBadge(theme, isCorrect, isSkipped),
                ],
              ),
              const SizedBox(height: 16),
              if (question.passage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showPassageDialog(context, question.passage!),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: Text(
                        question.passage!.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        backgroundColor: theme.brightness == Brightness.dark
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : theme.colorScheme.primary.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (question.instruction != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.instruction!.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichContentRenderer(
                          blocks: question.instruction!.content,
                          textStyle: TextStyle(
                            fontSize: 13,
                            color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              RichContentRenderer(
                blocks: question.content,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...List.generate(question.options.length, (index) {
          final option = question.options[index].key;
          final optionBlocks = question.options[index].content;

          final isThisCorrect = option == correctAnswer;
          final isUserChoice = option == userAnswer;

          Color bgColor = theme.colorScheme.surface;
          Color borderColor = theme.colorScheme.onSurface.withValues(
            alpha: 0.08,
          );
          IconData? trailingIcon;

          Color textColor = theme.colorScheme.onSurface;

          if (isThisCorrect) {
            bgColor = Colors.green.withValues(alpha: 0.06);
            borderColor = Colors.green.withValues(alpha: 0.4);
            trailingIcon = Icons.check_circle_rounded;
            textColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
          } else if (isUserChoice && !isCorrect) {
            bgColor = Colors.red.withValues(alpha: 0.06);
            borderColor = Colors.red.withValues(alpha: 0.4);
            trailingIcon = Icons.cancel_rounded;
            textColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: (isThisCorrect || (isUserChoice && !isCorrect))
                      ? 1.5
                      : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isThisCorrect
                          ? Colors.green
                          : (isUserChoice && !isCorrect)
                          ? Colors.red
                          : theme.colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: (isThisCorrect || (isUserChoice && !isCorrect))
                          ? Icon(
                        isThisCorrect ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 18,
                      )
                          : Text(
                        option,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichContentRenderer(
                      blocks: optionBlocks,
                      textStyle: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (trailingIcon != null)
                    Icon(
                      trailingIcon,
                      color: isThisCorrect ? Colors.green : Colors.red,
                      size: 22,
                    ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 10),

        _buildCorrectAnswerCard(
          theme,
          question,
          correctAnswer,
          userAnswer,
          isCorrect,
          isSkipped,
        ),

        if (question.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSolutionCard(theme, question),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCorrectAnswerCard(
      ThemeData theme,
      QuestionModel question,
      String correctAnswer,
      String? userAnswer,
      bool isCorrect,
      bool isSkipped,
      ) {
    final int correctIndex = question.options.indexWhere((opt) => opt.key == correctAnswer);

    final List<ContentBlockModel> correctBlocks =
    (correctIndex >= 0 && correctIndex < question.options.length)
        ? question.options[correctIndex].content
        : [
      ContentBlockModel(
        type: 'text',
        value: 'Option $correctAnswer',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Correct Answer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    correctAnswer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichContentRenderer(
                  blocks: correctBlocks,
                ),
              ),
            ],
          ),
          if (!isSkipped && !isCorrect && userAnswer != null) ...[
            const SizedBox(height: 12),
            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Your Answer:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    userAnswer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSolutionCard(ThemeData theme, QuestionModel question) {
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
    isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50;
    final iconColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Solution & Explanation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichContentRenderer(
            blocks: question.explanation,
            textStyle: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.normal,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
      ThemeData theme,
      bool isCorrect,
      bool isSkipped,
      ) {
    Color color;
    String label;
    IconData icon;

    if (isSkipped) {
      color = Colors.grey;
      label = 'Skipped';
      icon = Icons.remove_circle_outline_rounded;
    } else if (isCorrect) {
      color = Colors.green;
      label = 'Correct';
      icon = Icons.check_circle_rounded;
    } else {
      color = Colors.red;
      label = 'Wrong';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}