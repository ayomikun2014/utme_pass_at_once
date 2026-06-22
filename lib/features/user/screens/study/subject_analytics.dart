import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/bg.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/simulator_provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';

class SubjectAnalyticsScreen extends StatefulWidget {
  final String? examType;
  final String? schoolId;
  final String? sectionId;

  const SubjectAnalyticsScreen({
    super.key,
    this.examType,
    this.schoolId,
    this.sectionId,
  });

  @override
  State<SubjectAnalyticsScreen> createState() => _SubjectAnalyticsScreenState();
}

class _SubjectAnalyticsScreenState extends State<SubjectAnalyticsScreen> {
  bool _isLoading = true;

  // Aggregated subject data:
  // { subjectName: { correct, wrong, skipped, total, attempts } }
  final Map<String, Map<String, int>> _subjectStats = {};
  int _totalExams = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
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

  String _screenTitle() {
    final sectionId = widget.sectionId ??
        (widget.schoolId == null ? null : _sectionIdFromKey(widget.schoolId!));

    if (widget.examType?.toLowerCase() == 'post_utme' &&
        sectionId != null &&
        sectionId.trim().isNotEmpty) {
      final section = sectionId
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
          .join(' ');

      return '$section Analytics';
    }

    return 'Subject Analytics';
  }

  List<Map<String, dynamic>> _filterHistory(List<Map<String, dynamic>> history) {
    final targetExamType = widget.examType?.toLowerCase().trim();

    final targetSchoolId = widget.schoolId?.toLowerCase().trim();

    final targetBaseSchoolId = targetSchoolId == null
        ? null
        : _baseInstitutionId(targetSchoolId);

    final targetSectionId = widget.sectionId?.toLowerCase().trim() ??
        (targetSchoolId == null ? null : _sectionIdFromKey(targetSchoolId));

    List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(
      history,
    );

    if (targetExamType != null) {
      filtered = filtered.where((entry) {
        final config = Map<String, dynamic>.from(entry['examConfig'] ?? {});
        final hExam = config['examType']?.toString();

        if (hExam == null) return false;

        return hExam.toLowerCase().trim() == targetExamType;
      }).toList();
    }

    if (targetBaseSchoolId != null && targetExamType == 'post_utme') {
      filtered = filtered.where((entry) {
        final config = Map<String, dynamic>.from(entry['examConfig'] ?? {});

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

    return filtered;
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();

    final rawHistory = await simProvider.getExamHistory(authProvider);
    final history = _filterHistory(rawHistory);

    if (!mounted) return;

    _totalExams = history.length;
    _subjectStats.clear();

    for (final entry in history) {
      final results = Map<String, dynamic>.from(entry['results'] ?? {});
      final subjectScores = results.containsKey('subjectScores')
          ? Map<String, dynamic>.from(results['subjectScores'])
          : <String, dynamic>{};

      for (final subEntry in subjectScores.entries) {
        final subject = subEntry.key;
        final data = Map<String, dynamic>.from(subEntry.value as Map);

        final correct = (data['correct'] as int?) ?? 0;
        final wrong = (data['wrong'] as int?) ?? 0;
        final skipped = (data['skipped'] as int?) ?? 0;
        final total = (data['total'] as int?) ?? 0;

        if (!_subjectStats.containsKey(subject)) {
          _subjectStats[subject] = {
            'correct': 0,
            'wrong': 0,
            'skipped': 0,
            'total': 0,
            'attempts': 0,
          };
        }

        _subjectStats[subject]!['correct'] =
            _subjectStats[subject]!['correct']! + correct;

        _subjectStats[subject]!['wrong'] =
            _subjectStats[subject]!['wrong']! + wrong;

        _subjectStats[subject]!['skipped'] =
            _subjectStats[subject]!['skipped']! + skipped;

        _subjectStats[subject]!['total'] =
            _subjectStats[subject]!['total']! + total;

        _subjectStats[subject]!['attempts'] =
            _subjectStats[subject]!['attempts']! + 1;
      }
    }

    setState(() => _isLoading = false);
  }

  double _accuracy(Map<String, int> stats) {
    final total = stats['total'] ?? 0;

    if (total == 0) return 0;

    return (stats['correct'] ?? 0) / total * 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            onRefresh: _loadAnalytics,
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
                else if (_subjectStats.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(theme),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildOverviewPieChart(theme),
                        const SizedBox(height: 20),
                        _buildSubjectBarChart(theme),
                        const SizedBox(height: 20),
                        _buildStrongestWeakest(theme),
                        const SizedBox(height: 20),
                        _buildStudyRecommendations(theme),
                        const SizedBox(height: 20),
                        _buildSubjectDetailCards(theme),
                        const SizedBox(height: 30),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
              Icons.analytics_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Analytics Yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some exams in the simulator\nto see your performance breakdown.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Go Back',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPieChart(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    int totalCorrect = 0;
    int totalWrong = 0;
    int totalSkipped = 0;

    for (final stats in _subjectStats.values) {
      totalCorrect += stats['correct'] ?? 0;
      totalWrong += stats['wrong'] ?? 0;
      totalSkipped += stats['skipped'] ?? 0;
    }

    final totalQuestions = totalCorrect + totalWrong + totalSkipped;

    if (totalQuestions == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Distribution',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Across $_totalExams exam${_totalExams == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        if (totalCorrect > 0)
                          PieChartSectionData(
                            value: totalCorrect.toDouble(),
                            title: '$totalCorrect',
                            color: Colors.green,
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (totalWrong > 0)
                          PieChartSectionData(
                            value: totalWrong.toDouble(),
                            title: '$totalWrong',
                            color: Colors.red.shade400,
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (totalSkipped > 0)
                          PieChartSectionData(
                            value: totalSkipped.toDouble(),
                            title: '$totalSkipped',
                            color: Colors.grey.shade400,
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                      sectionsSpace: 3,
                      centerSpaceRadius: 35,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendDot(theme, 'Correct', Colors.green, totalCorrect),
                      const SizedBox(height: 10),
                      _legendDot(theme, 'Wrong', Colors.red.shade400, totalWrong),
                      if (totalSkipped > 0) ...[
                        const SizedBox(height: 10),
                        _legendDot(
                          theme,
                          'Skipped',
                          Colors.grey.shade400,
                          totalSkipped,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(
      ThemeData theme,
      String label,
      Color color,
      int value,
      ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectBarChart(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    final sortedSubjects = _subjectStats.entries.toList()
      ..sort((a, b) => _accuracy(b.value).compareTo(_accuracy(a.value)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accuracy Chart',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Performance % per subject',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final subject = sortedSubjects[group.x.toInt()].key;

                      return BarTooltipItem(
                        '${subject.toUpperCase()}\n${rod.toY.toStringAsFixed(1)}%',
                        TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value % 25 == 0) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();

                        if (idx >= 0 && idx < sortedSubjects.length) {
                          final name = sortedSubjects[idx].key.toUpperCase();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 5
                                  ? '${name.substring(0, 4)}.'
                                  : name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    );
                  },
                ),
                barGroups: List.generate(sortedSubjects.length, (i) {
                  final acc = _accuracy(sortedSubjects[i].value);
                  final color = _colorForAccuracy(acc);

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: acc,
                        color: color,
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.04,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrongestWeakest(ThemeData theme) {
    if (_subjectStats.length < 2) {
      return const SizedBox.shrink();
    }

    final isDark = theme.brightness == Brightness.dark;

    final sorted = _subjectStats.entries.toList()
      ..sort((a, b) => _accuracy(b.value).compareTo(_accuracy(a.value)));

    final strongest = sorted.first;
    final weakest = sorted.last;

    return Row(
      children: [
        Expanded(
          child: _buildHighlightCard(
            theme: theme,
            isDark: isDark,
            title: 'Strongest',
            subject: strongest.key,
            accuracy: _accuracy(strongest.value),
            icon: Icons.emoji_events_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildHighlightCard(
            theme: theme,
            isDark: isDark,
            title: 'Weakest',
            subject: weakest.key,
            accuracy: _accuracy(weakest.value),
            icon: Icons.trending_down_rounded,
            color: Colors.red.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subject,
    required double accuracy,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subject.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${accuracy.toStringAsFixed(1)}% accuracy',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDetailCards(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    final sorted = _subjectStats.entries.toList()
      ..sort((a, b) => _accuracy(b.value).compareTo(_accuracy(a.value)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Detailed Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        ...sorted.map((entry) {
          final name = entry.key;
          final stats = entry.value;
          final acc = _accuracy(stats);
          final total = stats['total'] ?? 0;
          final correct = stats['correct'] ?? 0;
          final wrong = stats['wrong'] ?? 0;
          final skipped = stats['skipped'] ?? 0;
          final attempts = stats['attempts'] ?? 0;
          final color = _colorForAccuracy(acc);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              ),
              boxShadow: isDark
                  ? null
                  : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      '${acc.toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '$total questions • $attempts exam${attempts == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: acc / 100,
                            backgroundColor: theme.colorScheme.onSurface
                                .withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.02,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _detailStat(
                                theme,
                                Icons.check_circle_rounded,
                                'Correct',
                                '$correct',
                                Colors.green,
                              ),
                              _detailStat(
                                theme,
                                Icons.cancel_rounded,
                                'Wrong',
                                '$wrong',
                                Colors.red.shade400,
                              ),
                              _detailStat(
                                theme,
                                Icons.remove_circle_outline_rounded,
                                'Skipped',
                                '$skipped',
                                Colors.grey,
                              ),
                              _detailStat(
                                theme,
                                Icons.repeat_rounded,
                                'Attempts',
                                '$attempts',
                                theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _detailStat(
      ThemeData theme,
      IconData icon,
      String label,
      String value,
      Color color,
      ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Color _colorForAccuracy(double acc) {
    if (acc >= 70) return Colors.green;
    if (acc >= 50) return Colors.orange;
    return Colors.red.shade400;
  }

  Widget _buildStudyRecommendations(ThemeData theme) {
    final sorted = _subjectStats.entries.toList()
      ..sort((a, b) => _accuracy(a.value).compareTo(_accuracy(b.value)));

    final weak = sorted.where((entry) => _accuracy(entry.value) < 70).take(3);

    if (weak.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.15),
              Colors.green.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Outstanding Job!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All your subjects are above 70% accuracy.\nYou are fully prepared!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
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
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tips_and_updates_rounded,
                  color: Colors.amber.shade800,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Study Recommendations',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Focus on these subjects to improve your overall score:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ...weak.map((entry) {
            final acc = _accuracy(entry.value);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colorForAccuracy(acc).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: _colorForAccuracy(acc),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${acc.toStringAsFixed(1)}% accuracy needs review',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}