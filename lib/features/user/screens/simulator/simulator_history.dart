import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'simulator_result.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/simulator_provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';

class SimulatorHistoryScreen extends StatefulWidget {
  final String? examType;
  final String? schoolId;
  final String? sectionId;

  const SimulatorHistoryScreen({
    super.key,
    this.examType,
    this.schoolId,
    this.sectionId,
  });

  @override
  State<SimulatorHistoryScreen> createState() => _SimulatorHistoryScreenState();
}

class _SimulatorHistoryScreenState extends State<SimulatorHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }



  String _baseInstitutionId(String id) {
    final lower = id.toLowerCase().trim();

    if (!lower.contains('_')) return lower;

    return lower.split('_').first;
  }

  String? _sectionIdFromKey(String id) {
    final lower = id.toLowerCase().trim();

    if (!lower.contains('_')) return null;

    final parts = lower.split('_');

    if (parts.length < 2) return null;

    return parts.sublist(1).join('_');
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();

    List<Map<String, dynamic>> history = await simProvider.getExamHistory(
      authProvider,
    );

    final targetExamType = widget.examType?.toLowerCase().trim();

    final targetSchoolId = widget.schoolId?.toLowerCase().trim();

    final targetBaseSchoolId = targetSchoolId == null
        ? null
        : _baseInstitutionId(targetSchoolId);

    final targetSectionId = widget.sectionId?.toLowerCase().trim() ??
        (targetSchoolId == null ? null : _sectionIdFromKey(targetSchoolId));

    if (targetExamType != null) {
      history = history.where((h) {
        final config = Map<String, dynamic>.from(h['examConfig'] ?? {});
        final hExam = config['examType']?.toString();

        if (hExam == null) return false;

        return hExam.toLowerCase().trim() == targetExamType;
      }).toList();
    }

    if (targetBaseSchoolId != null && targetExamType == 'post_utme') {
      history = history.where((h) {
        final config = Map<String, dynamic>.from(h['examConfig'] ?? {});

        final rawInstitution =
            config['institutionId']?.toString() ??
                config['centerCode']?.toString() ??
                config['schoolId']?.toString();

        if (rawInstitution == null) return false;

        final hBaseInstitution = _baseInstitutionId(rawInstitution);

        final hSectionId =
            config['sectionId']?.toString().toLowerCase().trim() ??
                _sectionIdFromKey(rawInstitution);

        final sameInstitution = hBaseInstitution == targetBaseSchoolId;

        final sameSection =
        targetSectionId == null ? true : hSectionId == targetSectionId;

        return sameInstitution && sameSection;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _openExamResult(Map<String, dynamic> entry) async {
    final simProvider = context.read<SimulatorProvider>();

    final examConfig = Map<String, dynamic>.from(entry['examConfig'] ?? {});
    final rawAnswers = Map<String, dynamic>.from(entry['subjectAnswers'] ?? {});
    final results = Map<String, dynamic>.from(entry['results'] ?? {});
    final totalQuestions = entry['totalQuestions'] as int? ?? 0;
    final timeTakenSeconds = entry['timeTakenSeconds'] as int? ?? 0;
    final timeTaken = Duration(seconds: timeTakenSeconds);

    final subjectAnswers = simProvider.parseSubjectAnswers(rawAnswers);
    final subjectQuestions = await simProvider.loadQuestionsForHistory(entry);

    if (subjectQuestions.isEmpty) {
      if (!mounted) return;

      CustomToast.show(context, 'This exam has no stored question data', isError: true);

      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimulatorResultScreen(
          results: results,
          totalQuestions: totalQuestions,
          timeTaken: timeTaken,
          subjectQuestions: subjectQuestions,
          subjectAnswers: subjectAnswers,
          examConfig: examConfig,
        ),
      ),
    );
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Exam?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently remove this exam from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final simProvider = context.read<SimulatorProvider>();

      await simProvider.deleteExamResult(authProvider, id);

      await _loadHistory();
    }
  }

  String _screenTitle() {
    if (widget.examType?.toLowerCase() == 'post_utme' &&
        widget.sectionId != null &&
        widget.sectionId!.trim().isNotEmpty) {
      final section = widget.sectionId!
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

      return '$section History';
    }

    return 'Exam History';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            onRefresh: _loadHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CustomAppBar(
                  title: _screenTitle(),
                  isLeading: true,
                  centerTitle: true,
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CustomLoader()),
                  )
                else if (_history.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(theme),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          if (index == 0) {
                            return _buildHeroCard(theme);
                          }

                          return _buildHistoryCard(
                            _history[index - 1],
                            theme,
                            index - 1,
                          );
                        },
                        childCount: _history.length + 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    final totalExams = _history.length;
    int totalCorrect = 0;
    int totalQuestions = 0;

    for (final entry in _history) {
      final results = Map<String, dynamic>.from(entry['results'] ?? {});
      totalCorrect += (results['score'] as int?) ?? 0;
      totalQuestions += (entry['totalQuestions'] as int?) ?? 0;
    }

    final avgPercent = totalQuestions > 0
        ? ((totalCorrect / totalQuestions) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Your Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Exams', '$totalExams'),
                      Container(
                        width: 1,
                        height: 35,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _buildStatItem('Avg Score', '$avgPercent%'),
                      Container(
                        width: 1,
                        height: 35,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _buildStatItem('Questions', '$totalQuestions'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Exam History',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed exams will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
      Map<String, dynamic> entry,
      ThemeData theme,
      int index,
      ) {
    final isDark = theme.brightness == Brightness.dark;

    final results = Map<String, dynamic>.from(entry['results'] ?? {});
    final examConfig = Map<String, dynamic>.from(entry['examConfig'] ?? {});
    final totalQuestions = entry['totalQuestions'] as int? ?? 0;
    final timeTakenSeconds = entry['timeTakenSeconds'] as int? ?? 0;
    final completedAt = DateTime.tryParse(entry['completedAt'] ?? '');
    final id = entry['id'] as String? ?? '';

    final score = results['score'] as int? ?? 0;

    final percentage = totalQuestions > 0
        ? ((score / totalQuestions) * 100).round()
        : 0;

    final passed = percentage >= 50;

    final examType = examConfig['examType'] as String? ?? '';
    final sectionName = examConfig['sectionName']?.toString();

    final badgeText = sectionName != null && sectionName.trim().isNotEmpty
        ? '${examType.toUpperCase()} • $sectionName'
        : examType.toUpperCase();

    final subjects = List<String>.from(examConfig['subjects'] ?? []);
    final timeTaken = Duration(seconds: timeTakenSeconds);

    final scoreColor = passed ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openExamResult(entry),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        passed ? 'PASSED' : 'FAILED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _deleteEntry(id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: passed
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.red.shade400, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scoreColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$score / $totalQuestions correct',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeTaken.inHours > 0
                                    ? '${timeTaken.inHours}:${(timeTaken.inMinutes % 60).toString().padLeft(2, '0')}:${(timeTaken.inSeconds % 60).toString().padLeft(2, '0')}'
                                    : '${timeTaken.inMinutes}:${(timeTaken.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              if (completedAt != null) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    completedAt.toString().split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.06,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subjects.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.06,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Text(
                        s.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}