import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_grid_card.dart';
import '../../utils/custom_fallback_image.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../auth/models/user_model.dart';
import 'eclassroom_center_categories_screen.dart';
import '../../providers/notification_provider.dart';
import '../../../../core/services/tutorial_service.dart';

class EClassroomScreen extends StatefulWidget {
  const EClassroomScreen({super.key});

  @override
  State<EClassroomScreen> createState() => _EClassroomScreenState();
}

class _EClassroomScreenState extends State<EClassroomScreen> {
  Map<String, String> _getCenters(UserModel? user) {
    if (user == null) return {};
    final centers = Map<String, String>.from(user.referredCenters);
    // Graceful fallback for single-referral legacy users
    if (centers.isEmpty && user.referredBy != null && user.referredBy!.isNotEmpty) {
      centers[user.referredBy!] = user.schoolStatus.isNotEmpty ? user.schoolStatus : 'eClassroom';
    }
    return centers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    final centers = _getCenters(user);
    final notificationProvider = context.watch<NotificationProvider>();
    final unreadNotifs = notificationProvider.notifications.where((n) => !n.isRead).toList();

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          AnimationLimiter(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 220.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'eClassrooms',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.0,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    centerTitle: true,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/eClassroom_subject_banner.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const CustomFallbackImage(
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        // Dark gradient overlay for text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20,
                    ),
                    child: Text(
                      'Your Centers',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (centers.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.school_outlined,
                              size: 48,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No eClassrooms Yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Purchase an exam section from an affiliated center to access your tests, study notes, and assignments.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final adminId = centers.keys.elementAt(index);
                          final centerName = centers[adminId]!;
                          final isSuspended = user?.suspendedCenters[adminId] == true;

                          final centerNotifCount = unreadNotifs.where((n) =>
                            (n.payload?['adminId'] == adminId || n.payload?['centerId'] == adminId) &&
                            (n.type == 'grade' || n.type == 'assignment' || n.type == 'notice' || n.type == 'test' || n.type == 'cbt')
                          ).length;
                          
                          Widget cardWidget = AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 600),
                            columnCount: 2,
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                      Opacity(
                                        opacity: isSuspended ? 0.5 : 1.0,
                                        child: CustomGridCard(
                                          title: centerName,
                                          route: '', // Handled by onTap
                                          onTap: () {
                                            if (isSuspended) {
                                              CustomToast.show(context, 'You have been suspended by this center. Please contact the administrator.', isError: true);
                                              return;
                                            }
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EClassroomCenterCategoriesScreen(
                                                  adminId: adminId,
                                                  centerName: centerName,
                                                ),
                                              ),
                                            );
                                          },
                                          baseColor: AppColors.primary,
                                          icon: Icons.account_balance_rounded,
                                          requiresNetwork: false,
                                        ),
                                      ),
                                      if (isSuspended)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade800,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Suspended',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (centerNotifCount > 0)
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              '$centerNotifCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          if (index == 0) {
                            cardWidget = TutorialService.instance.buildShowcase(
                              key: TutorialService.instance.eclassroomCentersKey,
                              title: 'Classroom Centers 🏫',
                              description: 'Access tests, assignments, notice boards, and study notes provided directly by your center administrators!',
                              context: context,
                              child: cardWidget,
                            );
                          }

                          return cardWidget;
                        },
                        childCount: centers.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
