import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:utme_pass_at_once/features/user/models/question_model.dart';

import '../../../../core/utils/custom_btn.dart';
import 'simulator_review.dart';

class SimulatorResultScreen extends StatelessWidget {
  final Map<String, dynamic> results;
  final int totalQuestions;
  final Duration timeTaken;
  final Map<String, List<QuestionModel>> subjectQuestions;
  final Map<String, Map<int, String>> subjectAnswers;
  final Map<String, dynamic> examConfig;
  final bool fromExam;

  const SimulatorResultScreen({
    super.key,
    required this.results,
    required this.totalQuestions,
    required this.timeTaken,
    required this.subjectQuestions,
    required this.subjectAnswers,
    required this.examConfig,
    this.fromExam = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final score = results['score'] as int? ?? 0;
    final correctAnswers = results['correctAnswers'] as int? ?? 0;
    final wrongAnswers = results['wrongAnswers'] as int? ?? 0;
    final skipped = results['skippedAnswers'] as int? ?? 0;

    final percentage = totalQuestions > 0
        ? (score / totalQuestions * 100).toInt()
        : 0;

    final passed = percentage >= 50;

    return PopScope(
      canPop: !fromExam,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (fromExam) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/exam_dashboard',
                (route) => route.isFirst,
            arguments: _dashboardArguments(),
          );
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(context, theme),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreHero(
                      theme,
                      score,
                      totalQuestions,
                      percentage,
                      passed,
                    ).animate()
                     .fadeIn(delay: 50.ms, duration: 600.ms)
                     .scale(delay: 50.ms, duration: 600.ms, curve: Curves.easeOutQuad),

                    const SizedBox(height: 20),

                    Text(
                      'PERFORMANCE STATS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 10),

                    _buildStatsGrid(
                      theme,
                      correctAnswers,
                      wrongAnswers,
                      skipped,
                      timeTaken,
                    ).animate()
                     .fadeIn(delay: 200.ms, duration: 600.ms)
                     .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

                    const SizedBox(height: 24),

                    if (results['subjectScores'] is Map<String, dynamic>) ...[
                      Text(
                        'SUBJECT PERFORMANCE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 10),
                      _buildSubjectBreakdown(
                        theme,
                        results['subjectScores'] as Map<String, dynamic>,
                      ).animate()
                       .fadeIn(delay: 350.ms, duration: 600.ms)
                       .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                    ],

                    const SizedBox(height: 20),

                    _buildActionButtons(
                      context,
                      theme,
                    ).animate()
                     .fadeIn(delay: 500.ms, duration: 600.ms)
                     .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _dashboardArguments() {
    return {
      'examType': examConfig['examType'] ?? 'post_utme',
      'schoolId': examConfig['institutionId'],
      'schoolName': examConfig['institutionName'],
      'logoUrl': examConfig['logoUrl'],
      'sectionId': examConfig['sectionId'],
      'sectionName': examConfig['sectionName'],
    };
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          final bool isClassroomTest = examConfig['isClassroomTest'] as bool? ?? false;
          if (isClassroomTest) {
            Navigator.of(context).pop();
          } else if (fromExam) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/exam_dashboard',
                  (route) => route.isFirst,
              arguments: _dashboardArguments(),
            );
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      title: const Text(
        'Exam Results',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
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
                Icons.assessment,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                examConfig['sectionName'] != null &&
                    examConfig['sectionName'].toString().trim().isNotEmpty
                    ? '${(examConfig['examType'] as String?)?.toUpperCase() ?? 'EXAM'} • ${examConfig['sectionName']}'
                    : (examConfig['examType'] as String?)?.toUpperCase() ?? 'EXAM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreHero(
    ThemeData theme,
    int score,
    int total,
    int percentage,
    bool passed,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = passed ? Colors.green.shade600 : Colors.red.shade500;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Floating Decorative Circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.25),
                      primaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.2),
                      primaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                children: [
                  // Animated Double Ring score indicator
                  AnimatedScoreRadial(
                    percentage: percentage.toDouble(),
                    score: score,
                    total: total,
                    passed: passed,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    passed ? 'Congratulations, Champion!' : 'Keep Pushing Forward!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ).animate().scale(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: 6),

                  Text(
                    passed
                        ? 'Excellent job! You passed the simulation with high flying colors.'
                        : 'Practice makes perfect. Review your mistakes to score higher next time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          passed ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          passed ? 'PASSED' : 'PRACTICE REQUIRED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: primaryColor,
                          ),
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
  }

  Widget _buildStatsGrid(
    ThemeData theme,
    int correct,
    int wrong,
    int skipped,
    Duration timeTaken,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.45,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          theme,
          title: 'Correct',
          value: '$correct',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),
        _buildStatCard(
          theme,
          title: 'Wrong',
          value: '$wrong',
          icon: Icons.cancel_rounded,
          color: Colors.red.shade400,
        ),
        _buildStatCard(
          theme,
          title: 'Skipped',
          value: '$skipped',
          icon: Icons.remove_circle_outline_rounded,
          color: Colors.grey.shade500,
        ),
        _buildStatCard(
          theme,
          title: 'Time Taken',
          value: _formatDuration(timeTaken),
          icon: Icons.timer_outlined,
          color: Colors.blue.shade500,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 48,
              color: color.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    final sub = subject.toLowerCase().trim();
    if (sub.contains('math')) return Colors.blue.shade600;
    if (sub.contains('chem')) return Colors.cyan.shade500;
    if (sub.contains('phy')) return Colors.deepPurple.shade500;
    if (sub.contains('bio')) return const Color(0xFF10B981);
    if (sub.contains('eng')) return Colors.orange.shade600;
    if (sub.contains('lit')) return Colors.pink.shade500;
    if (sub.contains('gov') || sub.contains('his')) return Colors.teal.shade600;
    return Colors.indigo.shade500;
  }

  Widget _buildSubjectBreakdown(
    ThemeData theme,
    Map<String, dynamic> subjectScores,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: subjectScores.entries.map((entry) {
        final subject = entry.key;
        final data = entry.value as Map<String, dynamic>;

        final score = data['score'] as int? ?? 0;
        final total = data['total'] as int? ?? 0;
        final correct = data['correct'] as int? ?? 0;
        final wrong = data['wrong'] as int? ?? 0;
        final skipped = data['skipped'] as int? ?? 0;

        final percentage = total > 0 ? (score / total * 100).toInt() : 0;
        final subColor = _getSubjectColor(subject);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              width: 1.2,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: subColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.book_outlined,
                            size: 16,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subject.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: subColor.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$score / $total ($percentage%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: subColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Custom Progress Bar with Glowing Ends
              Stack(
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: total > 0 ? (percentage / 100).clamp(0.0, 1.0) : 0.0,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            subColor.withValues(alpha: 0.7),
                            subColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: subColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Custom mini pills
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniPill(
                    theme,
                    label: 'Correct',
                    value: '$correct',
                    color: Colors.green,
                  ),
                  _buildMiniPill(
                    theme,
                    label: 'Wrong',
                    value: '$wrong',
                    color: Colors.red.shade400,
                  ),
                  _buildMiniPill(
                    theme,
                    label: 'Skipped',
                    value: '$skipped',
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniPill(
    ThemeData theme, {
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    final bool isClassroomTest = examConfig['isClassroomTest'] as bool? ?? false;
    final bool isPractice = examConfig['isPractice'] as bool? ?? false;

    if (isClassroomTest && !isPractice) {
      final deadlineStr = examConfig['deadline']?.toString();
      if (deadlineStr != null) {
        final deadline = DateTime.tryParse(deadlineStr);
        if (deadline != null && deadline.isAfter(DateTime.now())) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Review of answers will be unlocked once the admin test deadline has expired.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    final bool isFree = examConfig['isFree'] as bool? ?? false;

    return Column(
      children: [
        CustomBtn(
          label: 'Review Answers & Solutions',
          backgroundColor: theme.colorScheme.primary,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SimulatorReviewScreen(
                  subjectQuestions: subjectQuestions,
                  subjectAnswers: subjectAnswers,
                  examConfig: examConfig,
                ),
              ),
            );
          },
        ),
        if (isFree) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/store'),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unlock All Subjects & Years',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upgrade to Premium to get access to 15+ subjects, 10+ years of past questions for all institutions offline!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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

// Custom segment score radial ring indicator painter
class ScoreRadialPainter extends CustomPainter {
  final double percentage;
  final Color baseColor;
  final Color progressColor;

  ScoreRadialPainter({
    required this.percentage,
    required this.baseColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle track (outer)
    final outerBasePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, outerBasePaint);

    // Inner circle track
    final innerBasePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 14, innerBasePaint);

    if (percentage <= 0) return;

    // Outer progress arc
    final outerProgressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * 3.1415926535 * (percentage / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2,
      sweepAngle,
      false,
      outerProgressPaint,
    );

    // Inner progress arc
    final innerProgressPaint = Paint()
      ..color = progressColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 14),
      -3.1415926535 / 2,
      sweepAngle,
      false,
      innerProgressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScoreRadialPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.progressColor != progressColor;
  }
}

// Stateful Sub-Widget for Animated radial score
class AnimatedScoreRadial extends StatefulWidget {
  final double percentage;
  final int score;
  final int total;
  final bool passed;

  const AnimatedScoreRadial({
    super.key,
    required this.percentage,
    required this.score,
    required this.total,
    required this.passed,
  });

  @override
  State<AnimatedScoreRadial> createState() => _AnimatedScoreRadialState();
}

class _AnimatedScoreRadialState extends State<AnimatedScoreRadial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.percentage).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressColor = widget.passed ? Colors.green.shade500 : Colors.red.shade500;
    final baseColor = isDark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(170, 170),
                painter: ScoreRadialPainter(
                  percentage: _animation.value,
                  baseColor: baseColor,
                  progressColor: progressColor,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_animation.value.toInt()}%',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.score} / ${widget.total}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SCORE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white30 : Colors.black38,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
