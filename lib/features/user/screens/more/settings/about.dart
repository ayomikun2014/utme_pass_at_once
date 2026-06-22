import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'About',
                subtitle: 'Learn about the purpose and features of the system.',
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. App Introduction Card
                      _buildSectionCard(
                        context,
                        icon: Icons.school_outlined,
                        title: 'PASS AT ONCE CBT',
                        child: Text(
                          'Welcome to PASS AT ONCE CBT, the premier digital exam preparation and classroom collaboration platform designed specifically for Nigerian students.\n\n'
                          'Our mission is to empower senior secondary school candidates and university aspirants to prepare effectively, build academic confidence, and excel in their foundational examinations, including the UTME (JAMB), WAEC, NECO, and secondary school entrance Post-UTME tests.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Our Mission
                      _buildSectionCard(
                        context,
                        icon: Icons.flag_outlined,
                        title: 'Our Mission',
                        child: Text(
                          'In a rapidly evolving educational ecosystem where computer-based testing (CBT) has become the gold standard for university admissions in Nigeria, candidates require more than just textbooks. They need a simulated environment that mirrors the time pressure, layout, and visual feedback of actual national exams.\n\n'
                          'PASS AT ONCE CBT bridges the gap by delivering a premium, highly responsive offline exam simulation tool paired with real-time academic collaboration. We provide the technical structure, verified question banks, and learning metrics necessary for continuous, self-paced learning success.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 3. What We Provide
                      _buildSectionCard(
                        context,
                        icon: Icons.rocket_launch_outlined,
                        title: 'What We Provide',
                        child: Column(
                          children: [
                            _buildAimItem(
                              context,
                              Icons.timer_outlined,
                              'High-Fidelity Exam Simulation',
                              'Practice with real past questions configured to duplicate the official UTME, WAEC, and NECO timing, layouts, and subject counts. Build familiarity with CBT systems to eliminate test-day anxiety.',
                            ),
                            _buildAimItem(
                              context,
                              Icons.menu_book_outlined,
                              'Interactive Study Notes & Syllabi',
                              'Access comprehensive lesson notes, official syllabus breakdowns, and institutional brochures organized logically by subject and topic to ensure highly focused preparation.',
                            ),
                            _buildAimItem(
                              context,
                              Icons.insights_outlined,
                              'Performance & Progress Insights',
                              'Our user-centric stats engine tracks your strengths and weaknesses. Review correct, wrong, and skipped metrics inside our majestic results layouts to focus your energy on subjects that need improvement.',
                            ),
                            _buildAimItem(
                              context,
                              Icons.groups_outlined,
                              'E-Classroom Collaboration',
                              'Synchronize your study progress directly with your school, tutoring center, or private teachers. Receive class notices, take center-supervised mock exams, and submit homework assignments seamlessly inside the app.',
                            ),
                            _buildAimItem(
                              context,
                              Icons.psychology_outlined,
                              'Advanced AI Tutor',
                              'Get immediate explanations and step-by-step academic solutions using our advanced, interactive AI study helper.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 4. Developer & Support Team
                      _buildSectionCard(
                        context,
                        icon: Icons.handyman_outlined,
                        title: 'Developer & Support Team',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PASS AT ONCE CBT is designed, developed, and maintained by Funtech Programming Consultants, a dedicated educational technology firm committed to building high-performance digital tools for schools and self-directed learners across West Africa.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            _buildSupportRow(
                              context,
                              Icons.business_rounded,
                              'Developer Group',
                              'Funtech Programming Consultants',
                            ),
                            const SizedBox(height: 10),
                            _buildSupportRow(
                              context,
                              Icons.email_outlined,
                              'Support Email',
                              'taiwoprints999@gmail.com',
                            ),
                            const SizedBox(height: 10),
                            _buildSupportRow(
                              context,
                              Icons.schedule_outlined,
                              'Official Hours',
                              'Monday - Saturday, 8:00 AM - 6:00 PM',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 5. Footer
                      Center(
                        child: Column(
                          children: [
                            Builder(
                              builder: (context) {
                                final version = context.watch<SettingsProvider>().installedVersion;
                                return Text(
                                  'Version $version',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '© 2026 PASS AT ONCE CBT',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Developed by Funtech Programming Consultants',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
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
    );
  }

  // --- SECTION CARD WIDGET ---
  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // --- AIM ITEM WIDGET ---
  Widget _buildAimItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SUPPORT ROW WIDGET ---
  Widget _buildSupportRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
