import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/bg.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/simulator_provider.dart';
import 'subject_analytics.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';

class PerformanceAnalysisScreen extends StatefulWidget {
  final String? examType;
  final String? schoolId;
  final String? sectionId;

  const PerformanceAnalysisScreen({
    super.key,
    this.examType,
    this.schoolId,
    this.sectionId,
  });

  @override
  State<PerformanceAnalysisScreen> createState() =>
      _PerformanceAnalysisScreenState();
}

class _PerformanceAnalysisScreenState extends State<PerformanceAnalysisScreen> {
  bool _isLoading = true;
  int _totalExams = 0;
  double _avgScore = 0;
  int _bestScore = 0;
  int _totalQuestions = 0;
  int _totalCorrect = 0;
  List<_TrendPoint> _trendData = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
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

      return '$section Performance';
    }

    return 'Performance Analysis';
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

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();

    final rawHistory = await simProvider.getExamHistory(authProvider);
    final history = _filterHistory(rawHistory);

    if (!mounted) return;

    _totalExams = history.length;

    if (history.isEmpty) {
      setState(() {
        _avgScore = 0;
        _bestScore = 0;
        _totalQuestions = 0;
        _totalCorrect = 0;
        _trendData = [];
        _isLoading = false;
      });

      return;
    }

    double scoreSum = 0;
    int best = 0;
    int questionsSum = 0;
    int correctSum = 0;
    final trend = <_TrendPoint>[];

    final chronological = history.reversed.toList();

    for (int i = 0; i < chronological.length; i++) {
      final entry = chronological[i];
      final results = Map<String, dynamic>.from(entry['results'] ?? {});
      final total = entry['totalQuestions'] as int? ?? 0;
      final score = results['score'] as int? ?? 0;
      final correct = results['correctAnswers'] as int? ?? score;
      final pct = total > 0 ? (score / total * 100).round() : 0;

      scoreSum += pct;

      if (pct > best) {
        best = pct;
      }

      questionsSum += total;
      correctSum += correct;

      trend.add(
        _TrendPoint(
          index: i,
          percentage: pct.toDouble(),
        ),
      );
    }

    setState(() {
      _avgScore = scoreSum / _totalExams;
      _bestScore = best;
      _totalQuestions = questionsSum;
      _totalCorrect = correctSum;
      _trendData = trend;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            onRefresh: _loadStats,
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
                else if (_totalExams == 0)
                  SliverFillRemaining(
                    child: _buildEmptyState(theme),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeroCard(theme)
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 20),
                        _buildOverviewCards(theme)
                            .animate()
                            .fadeIn(delay: 100.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 20),
                        _buildTrendChart(theme)
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.1),
                        const SizedBox(height: 24),
                        _buildNavigationCards(theme)
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.1),
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

  Widget _buildHeroCard(ThemeData theme) {
    final overallAccuracy = _totalQuestions > 0
        ? (_totalCorrect / _totalQuestions * 100)
        : 0.0;

    return Container(
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
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  )
                      .animate(
                    onPlay: (controller) =>
                        controller.repeat(reverse: true),
                  )
                      .scaleXY(end: 1.1, duration: 1.seconds),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Performance',
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
                    _buildHeroStat('Exams', '$_totalExams'),
                    _buildHeroDivider(),
                    _buildHeroStat('Avg', '${_avgScore.toStringAsFixed(0)}%'),
                    _buildHeroDivider(),
                    _buildHeroStat('Best', '$_bestScore%'),
                    _buildHeroDivider(),
                    _buildHeroStat(
                      'Accuracy',
                      '${overallAccuracy.toStringAsFixed(0)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
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

  Widget _buildHeroDivider() {
    return Container(
      width: 1,
      height: 35,
      color: Colors.white.withValues(alpha: 0.2),
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
              Icons.query_stats_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Performance Data',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some exams to see your\nperformance analysis here.',
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

  Widget _buildOverviewCards(ThemeData theme) {
    final overallAccuracy = _totalQuestions > 0
        ? (_totalCorrect / _totalQuestions * 100)
        : 0.0;

    return Column(
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
                Icons.dashboard_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Overview',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                theme,
                icon: Icons.quiz_rounded,
                label: 'Exams Taken',
                value: '$_totalExams',
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                theme,
                icon: Icons.trending_up_rounded,
                label: 'Avg Score',
                value: '${_avgScore.toStringAsFixed(1)}%',
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                theme,
                icon: Icons.emoji_events_rounded,
                label: 'Best Score',
                value: '$_bestScore%',
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                theme,
                icon: Icons.check_circle_rounded,
                label: 'Accuracy',
                value: '${overallAccuracy.toStringAsFixed(1)}%',
                color: Colors.purple.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
      ThemeData theme, {
        required IconData icon,
        required String label,
        required String value,
        required Color color,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(ThemeData theme) {
    if (_trendData.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_graph_rounded,
                size: 36,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Score Trend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete at least 2 exams to map your progress trend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final data = _trendData.length > 10
        ? _trendData.sublist(_trendData.length - 10)
        : _trendData;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
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
                  Icons.auto_graph_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Score Trend',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Last ${data.length} exams',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
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
                titlesData: FlTitlesData(
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
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '#${value.toInt() + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.percentage,
                      );
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: theme.colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: theme.colorScheme.primary,
                          strokeWidth: 2.5,
                          strokeColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.25),
                          theme.colorScheme.primary.withValues(alpha: 0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCards(ThemeData theme) {
    return Column(
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
                Icons.explore_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Explore Deeper',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _navCard(
          theme,
          icon: Icons.pie_chart_rounded,
          title: 'Subject-Wise Analytics',
          subtitle: 'See your strengths and weaknesses by subject',
          color: Colors.blue.shade600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubjectAnalyticsScreen(
                  examType: widget.examType,
                  schoolId: widget.schoolId,
                  sectionId: widget.sectionId,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _navCard(
          theme,
          icon: Icons.history_rounded,
          title: 'Exam History',
          subtitle: 'Review all your past exams and solutions',
          color: Colors.green.shade600,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/utme_history',
              arguments: {
                'examType': widget.examType,
                'schoolId': widget.schoolId,
                'sectionId': widget.sectionId,
              },
            );
          },
        ),
      ],
    );
  }

  Widget _navCard(
      ThemeData theme, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.1)),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: color.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendPoint {
  final int index;
  final double percentage;

  const _TrendPoint({
    required this.index,
    required this.percentage,
  });
}