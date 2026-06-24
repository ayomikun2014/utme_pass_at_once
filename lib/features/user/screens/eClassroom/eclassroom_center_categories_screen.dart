
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_grid_card.dart';
import '../../utils/custom_fallback_image.dart';

import 'test_subject_list_screen.dart';
import 'assignment_subject_list_screen.dart';
import 'study_note_subject_list_screen.dart';
import 'notice_board_screen.dart';
import 'center_leaderboard_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class EClassroomCenterCategoriesScreen extends StatefulWidget {
  final String adminId;
  final String centerName;

  const EClassroomCenterCategoriesScreen({
    super.key,
    required this.adminId,
    required this.centerName,
  });

  @override
  State<EClassroomCenterCategoriesScreen> createState() => _EClassroomCenterCategoriesScreenState();
}

class _EClassroomCenterCategoriesScreenState extends State<EClassroomCenterCategoriesScreen> {


  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final unreadNotifs = notificationProvider.notifications.where((n) => !n.isRead).toList();

    return Scaffold(
      body: Builder(
        builder: (context) {
          final centerName = widget.centerName;
          final referredBy = widget.adminId;
          
          final List<Map<String, dynamic>> categories = [
            {
              'title': 'Tests',
              'icon': Icons.quiz_rounded,
              'color': AppColors.primary,
              'badgeCount': unreadNotifs.where((n) =>
                (n.payload?['adminId'] == referredBy || n.payload?['centerId'] == referredBy) &&
                (n.type == 'test' || n.type == 'cbt')
              ).length,
              'onTap': () {
                final user = context.read<AuthProvider>().currentUser;
                if (user != null) {
                  context.read<NotificationProvider>().markCategoryNotificationsAsRead(
                    uid: user.uid,
                    adminId: referredBy,
                    types: ['test', 'cbt'],
                  );
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TestSubjectListScreen(adminId: referredBy),
                  ),
                );
              },
            },
            {
              'title': 'Assignments',
              'icon': Icons.assignment_rounded,
              'color': Colors.orange,
              'badgeCount': unreadNotifs.where((n) =>
                (n.payload?['adminId'] == referredBy || n.payload?['centerId'] == referredBy) &&
                (n.type == 'grade' || n.type == 'assignment')
              ).length,
              'onTap': () {
                final user = context.read<AuthProvider>().currentUser;
                if (user != null) {
                  context.read<NotificationProvider>().markCategoryNotificationsAsRead(
                    uid: user.uid,
                    adminId: referredBy,
                    types: ['grade', 'assignment'],
                  );
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignmentSubjectListScreen(adminId: referredBy),
                  ),
                );
              },
            },
            {
              'title': 'Study Notes',
              'icon': Icons.menu_book_rounded,
              'color': Colors.teal,
              'badgeCount': 0,
              'onTap': () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudyNoteSubjectListScreen(adminId: referredBy),
                    ),
                  ),
            },
            {
              'title': 'Notice Board',
              'icon': Icons.notifications_active_rounded,
              'color': Colors.redAccent,
              'badgeCount': unreadNotifs.where((n) =>
                (n.payload?['adminId'] == referredBy || n.payload?['centerId'] == referredBy) &&
                n.type == 'notice'
              ).length,
              'onTap': () {
                final user = context.read<AuthProvider>().currentUser;
                if (user != null) {
                  context.read<NotificationProvider>().markCategoryNotificationsAsRead(
                    uid: user.uid,
                    adminId: referredBy,
                    types: ['notice'],
                  );
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeBoardScreen(adminId: referredBy),
                  ),
                );
              },
            },
            {
              'title': 'Leaderboard',
              'icon': Icons.emoji_events_rounded,
              'color': Colors.amber.shade700,
              'badgeCount': 0,
              'onTap': () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CenterLeaderboardScreen(adminId: referredBy),
                    ),
                  ),
            },
          ];

          return Stack(
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
                        title: Text(
                          centerName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                              'assets/images/eclassroom_banner.webp',
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
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final cat = categories[index];
                            final badgeCount = cat['badgeCount'] as int? ?? 0;
                            
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 600),
                              columnCount: 2,
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomGridCard(
                                        title: cat['title'],
                                        route: '', // Handled by onTap
                                        onTap: cat['onTap'],
                                        baseColor: cat['color'],
                                        icon: cat['icon'],
                                        requiresNetwork: false,
                                      ),
                                      if (badgeCount > 0)
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
                                              '$badgeCount',
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
                          },
                          childCount: categories.length,
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
          );
        },
      ),
    );
  }
}
