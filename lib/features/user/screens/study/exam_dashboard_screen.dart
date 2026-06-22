import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_grid_card.dart';
import '../../models/ui_grid_card_details.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ExamDashboardScreen extends StatelessWidget {
  final String examType;
  final String? schoolId;
  final String? schoolName;
  final String? logoUrl;
  final String? sectionId;

  const ExamDashboardScreen({
    super.key,
    required this.examType,
    this.schoolId,
    this.schoolName,
    this.logoUrl,
    this.sectionId,
  });

  @override
  Widget build(BuildContext context) {
    // Determine dashboard title
    final String title = 'Dashboard';
    final bool isPostUtme = examType.toLowerCase() == 'post_utme';

    String? resolvedSectionId = sectionId;

    if (resolvedSectionId == null &&
        examType.toLowerCase() == 'post_utme' &&
        schoolId != null &&
        schoolId!.contains('_')) {
      final parts = schoolId!.toLowerCase().split('_');
      resolvedSectionId = parts.sublist(1).join('_');
    }

    // Pick the correct item list
    final List<GridCardModel> dashboardItems;
    if (isPostUtme && schoolId != null) {
      dashboardItems = postUtmeDashboardItems(
        examType,
        schoolId!,
        schoolName ?? schoolId!.toUpperCase(),
        logoUrl,
        sectionId: resolvedSectionId,
      );
    } else {
      dashboardItems = standardExamDashboardItems(examType);
    }

    // Choose accent color per exam type
    final Color accentColor;
    switch (examType.toLowerCase()) {
      case 'jamb':
        accentColor = AppColors.dynamicColors[2]; // Green
        break;
      case 'waec':
        accentColor = AppColors.dynamicColors[3]; // Amber
        break;
      case 'neco':
        accentColor = AppColors.dynamicColors[1]; // Red
        break;
      case 'post_utme':
        accentColor = AppColors.dynamicColors[4]; // Purple
        break;
      default:
        accentColor = AppColors.dynamicColors[0]; // Teal
    }

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          AnimationLimiter(
            child: CustomScrollView(
              slivers: [
                CustomAppBar(
                  title: title,
                  subtitle: _subtitleFor(examType),
                  // FIXED: Enforced white text for contrast against the colored app bar
                  subtitleStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  logoUrl: logoUrl,
                  color: accentColor.withValues(alpha: 0.9),
                  isLeading: true,
                  centerTitle: true,
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16,
                  ),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final feature = dashboardItems[index];
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 600),
                        columnCount: 2,
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: CustomGridCard(
                              title: feature.title,
                              route: feature.route,
                              baseColor: feature.baseColor,
                              icon: feature.icon,
                              imagePath: feature.imagePath,
                              arguments: feature.arguments,
                              requiresNetwork: feature.requiresNetwork,
                            ),
                          ),
                        ),
                      );
                    }, childCount: dashboardItems.length),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                  ),
                ),
                // Bottom padding to clear floating nav bar
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(String examType) {
    switch (examType.toLowerCase()) {
      case 'jamb':
        return 'JAMB UTME';
      case 'waec':
        return 'WAEC';
      case 'neco':
        return 'NECO';
      case 'post_utme':
        final school = schoolName ?? (schoolId?.toUpperCase() ?? 'Post-UTME');
        return school;
      default:
        return 'Your Exams';
    }
  }
}