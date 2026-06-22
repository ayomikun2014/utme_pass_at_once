import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/routes.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';

class AdmissionGuidelineLandingScreen extends StatelessWidget {
  const AdmissionGuidelineLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Admission Guideline',
                subtitle: 'Check requirements and cut-off marks',
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    _buildOptionCard(
                      context,
                      title: 'Admission Requirements',
                      subtitle: 'Check O\'Level & UTME requirements for all courses',
                      icon: Icons.assignment_turned_in_rounded,
                      // FIXED: Using AppColors instead of hardcoded Material colors
                      color: isDark ? AppColors.surfaceDark : AppColors.dynamicColors[0].withValues(alpha: 0.1),
                      iconColor: AppColors.dynamicColors[0],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.admissionRequirements,
                        arguments: args,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildOptionCard(
                      context,
                      title: 'Cut Off Marks',
                      subtitle: 'View merit, catchment & ELDS cut-off marks',
                      icon: Icons.trending_up_rounded,
                      color: isDark ? AppColors.surfaceDark : AppColors.dynamicColors[3].withValues(alpha: 0.1),
                      iconColor: AppColors.dynamicColors[3],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.admissionCutOffs,
                        arguments: args,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Color iconColor,
        required VoidCallback onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : iconColor.withValues(alpha: 0.2),
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: iconColor),
              ),
              const SizedBox(height: 20),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}