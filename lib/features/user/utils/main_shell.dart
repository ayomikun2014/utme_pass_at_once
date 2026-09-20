import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:utme_pass_at_once/features/user/providers/announcement_provider.dart';
import 'package:utme_pass_at_once/features/user/screens/more/announcements/announcement_carousel_dialog.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:utme_pass_at_once/core/constants/app_colors.dart';

import 'package:utme_pass_at_once/features/user/utils/ai_message_renderer.dart';

import '../../../../core/utils/custom_loader.dart';

import '../models/chat_message.dart';

import '../providers/ai_provider.dart';

import '../../auth/providers/auth_provider.dart';

import '../../../core/services/notification_service.dart';

import '../../../routes.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../screens/home.dart';

import '../screens/more.dart';

import '../screens/study.dart';

import '../providers/notification_provider.dart';
import '../providers/simulator_provider.dart';
import '../screens/eClassroom/eclassroom_screen.dart';
import '../screens/videos/video_subjects_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/services/tutorial_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  // ignore: library_private_types_in_public_api
  static final GlobalKey<_MainShellState> shellKey =
      GlobalKey<_MainShellState>();

  static void switchTab(int index) {
    shellKey.currentState?._switchTo(index);
  }

  static void openAIChat(BuildContext context) {
    debugPrint('MainShell: openAIChat triggered from context: $context');

    final state = shellKey.currentState;

    if (state == null) {
      debugPrint(
        'MainShell Error: shellKey.currentState is NULL. This means the MainShell widget is not currently mounted with the static shellKey.',
      );

      final foundState = context.findAncestorStateOfType<_MainShellState>();

      if (foundState != null) {
        debugPrint(
          'MainShell: Found state via ancestor lookup. Opening chat...',
        );

        foundState._showChatSheet(context);
      } else {
        debugPrint(
          'MainShell Error: Could not find MainShell state even via ancestor lookup.',
        );
      }

      return;
    }

    state._showChatSheet(context);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  bool _isNavVisible = true;
  bool _showTooltip = true;
  Timer? _tooltipTimer;

  StreamSubscription<QuerySnapshot>? _notifSubscription;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAppLaunchChecks();
    });

    _startTooltipCycle();
  }

  @override
  void dispose() {
    _pageController.dispose();

    _notifSubscription?.cancel();
    _tooltipTimer?.cancel();

    super.dispose();
  }

  void _startTooltipCycle() {
    // Hide initially after 8 seconds
    Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showTooltip = false;
        });
      }
    });

    // Show for 8 seconds every 45 seconds
    _tooltipTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) {
        setState(() {
          _showTooltip = true;
        });
      }
      Timer(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            _showTooltip = false;
          });
        }
      });
    });
  }

  Future<void> _runAppLaunchChecks() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    if (mounted) {
      context.read<NotificationProvider>().fetchNotifications(user.uid);
    }

    // ── Real-time listener for admin-sent notifications ──
    _notifSubscription?.cancel();
    bool isFirstSnapshot = true;
    _notifSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (isFirstSnapshot) {
            isFirstSnapshot = false;
            return;
          }
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added && change.doc.exists) {
              final data = change.doc.data();
              if (data == null) continue;

              // Mitigated double-sound issue: Admin-sourced notifications are already sent via standard
              // FCM push notifications and handled by the foreground Firebase Messaging listener.
              // Triggering local tray alerts from Firestore changes here is redundant and causes double sounds/popups.
              /*
          final title = data['title'] as String? ?? '';
          final body = data['body'] as String? ?? '';
          final payload = data['payload'] as Map<String, dynamic>?;
          final isRead = data['isRead'] as bool? ?? false;
          final fcmSent = data['fcmSent'] as bool? ?? false;
          final source = data['source'] as String? ?? '';

          if (!isRead && title.isNotEmpty && !fcmSent && source != 'client' && source != 'system') {
            NotificationService.instance.showPushNotification(
              title: title,
              body: body,
              payload: payload,
            );
          }
          */
            }
          }
        });

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // ── Silent Background Cache TTL Sync (3-Day Interval) ──
    final lastCacheCheckStr = prefs.getString('last_cache_update_check');
    bool shouldCheckCache = false;
    if (lastCacheCheckStr == null) {
      shouldCheckCache = true;
    } else {
      final lastCheck = DateTime.tryParse(lastCacheCheckStr);
      if (lastCheck != null && now.difference(lastCheck).inDays >= 3) {
        shouldCheckCache = true;
      }
    }

    if (shouldCheckCache) {
      unawaited(() async {
        try {
          final simProvider = context.read<SimulatorProvider>();
          final activeExams = ['post_utme', 'waec', 'jamb', 'neco'];
          final deviceId = auth.currentDeviceId;

          for (final exam in activeExams) {
            if (user.hasActiveExam(exam, deviceId)) {
              final centers = user.getExamCenters(exam);

              for (final center in centers) {
                final section = user.getSectionForInstitution(exam, center);
                final baseInstitutionId =
                    exam == 'post_utme' && center.contains('_')
                    ? center.split('_').first
                    : center;

                final updateInfo = await simProvider.checkForUpdates(
                  examType: exam,
                  institutionId: baseInstitutionId,
                  sectionId: section?['id'],
                );

                if (updateInfo['updatesAvailable'] == true) {
                  debugPrint(
                    '🔄 Silent sync: updates found for $exam/$baseInstitutionId. Downloading...',
                  );
                  await simProvider.downloadActivationData(
                    examType: exam,
                    institutionId: baseInstitutionId,
                    subjects: user.getSubjectsForCenter(exam, center),
                    sectionId: section?['id'],
                  );
                }
              }
            }
          }
          await prefs.setString(
            'last_cache_update_check',
            DateTime.now().toIso8601String(),
          );
          debugPrint('🔄 Silent sync: Completed successfully!');
        } catch (e) {
          debugPrint('🔄 Silent sync error: $e');
        }
      }());
    }

    final lastOpenedStr = prefs.getString('last_opened_date');
    if (lastOpenedStr != null) {
      final lastOpened = DateTime.tryParse(lastOpenedStr);
      if (lastOpened != null) {
        final diff = now.difference(lastOpened).inDays;
        if (diff >= 3) {
          final lastInactiveRemind = prefs.getString('last_inactive_remind');
          bool shouldShow = true;
          if (lastInactiveRemind != null) {
            final lastRemind = DateTime.tryParse(lastInactiveRemind);
            if (lastRemind != null && now.difference(lastRemind).inHours < 24) {
              shouldShow = false;
            }
          }

          if (shouldShow) {
            NotificationService.instance.createInAppNotification(
              uid: user.uid,
              title: 'Welcome Back! 👋',
              body: "It's been a while! Let's crush some study goals today.",
              type: 'inactive_reminder',
              showLocalPush: false,
            );
            await prefs.setString(
              'last_inactive_remind',
              now.toIso8601String(),
            );
          }
        }
      }
    }
    await prefs.setString('last_opened_date', now.toIso8601String());

    final expiry = user.premiumExpiryDate;
    final daysLeft = expiry.difference(now).inDays;

    if (user.isPremium && daysLeft <= 7 && daysLeft >= 0) {
      final lastExpiryRemind = prefs.getString('last_expiry_remind_date');
      bool shouldRemind = true;

      if (lastExpiryRemind != null) {
        final lastRemind = DateTime.tryParse(lastExpiryRemind);
        if (lastRemind != null &&
            lastRemind.year == now.year &&
            lastRemind.month == now.month &&
            lastRemind.day == now.day) {
          shouldRemind = false;
        }
      }

      if (shouldRemind) {
        NotificationService.instance.createInAppNotification(
          uid: user.uid,
          title: 'Premium Expiring Soon! ⏰',
          body:
              'Your premium access expires in $daysLeft day(s). Renew now to keep enjoying offline access and all subjects!',
          type: 'premium_expiring',
        );
        await prefs.setString('last_expiry_remind_date', now.toIso8601String());
      }
    }

    if (mounted) {
      await TutorialService.instance.checkAndShowTutorial(context);
    }

    // --- Global Announcement check ---
    if (mounted) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic('all');
        if (!mounted) return;
        final announcementProvider = context.read<AnnouncementProvider>();
        await announcementProvider.fetchAnnouncements();
        final unseen = announcementProvider.getUnseenAnnouncements();
        if (unseen.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AnnouncementCarouselDialog(
              announcements: unseen,
              onDismiss: () {
                announcementProvider.markAllAsSeen();
              },
            ),
          );
        }
      } catch (e) {
        debugPrint('Announcement check error: $e');
      }
    }
  }

  void _dismissTutorialShowcase() {
    final activeContext = TutorialService.instance.showcaseContext;
    if (activeContext != null && activeContext.mounted) {
      try {
        ShowCaseWidget.of(activeContext).dismiss();
      } catch (_) {}
    }
  }

  void _switchTo(int index) {
    _dismissTutorialShowcase();
    setState(() {
      _currentIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // Extra bottom offset so the nav clears on-screen gesture bars (back/home buttons)
    final systemNavPad = MediaQuery.of(context).padding.bottom;
    final bottomPad = isKeyboardOpen
        ? -100.0
        : (systemNavPad > 0 ? systemNavPad + 8.0 : 28.0);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final showEClassroom =
        user != null &&
        user.referredBy != null &&
        user.referredBy!.isNotEmpty &&
        user.referredBy != '--';

    final pages = [
      const Home(),
      const Study(),
      const VideoSubjectsScreen(),
      if (showEClassroom) const EClassroomScreen(),
      const More(),
    ];

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return ShowCaseWidget(
      onStart: (index, key) {
        debugPrint('🎬 Onboarding Tutorial: step $index started');
      },
      onComplete: (index, key) {
        debugPrint('🎬 Onboarding Tutorial: step $index completed');
      },
      onFinish: () {
        debugPrint('🎬 Onboarding Tutorial: finished');
        TutorialService.instance.completeTutorial(context);
      },
      builder: (showcaseCtx) {
        TutorialService.instance.showcaseContext = showcaseCtx;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (safeIndex != 0) {
              // If we are in any other tab than home, switch back to home
              _dismissTutorialShowcase();
              setState(() {
                _currentIndex = 0;
                _isNavVisible = true;
              });
              if (_pageController.hasClients) {
                _pageController.jumpToPage(0);
              }
              return;
            }

            // If we are on the Home tab
            final now = DateTime.now();
            if (_lastBackPressTime == null ||
                now.difference(_lastBackPressTime!) >
                    const Duration(seconds: 2)) {
              _lastBackPressTime = now;
              CustomToast.show(
                context,
                "Press back again to exit UTME Pass At Once",
                isError: false,
                duration: const Duration(seconds: 2),
              );
            } else {
              // Exit the app
              await SystemNavigator.pop();
            }
          },
          child: Scaffold(
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(
                bottom: 90.0,
              ), // Elevate above bottom bar
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: _showTooltip ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    child: AnimatedOpacity(
                      opacity: _showTooltip ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: _showTooltip
                            ? () => MainShell.openAIChat(context)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Colors.purpleAccent],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Stuck activating? Tap here! 💡',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => MainShell.openAIChat(context),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            Color(0xFF14B8A6), // Lighter brand teal
                            Colors.purpleAccent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.purpleAccent.withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Subtle inner glowing border/ring
                          Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                          ),
                          Image.asset(
                            'assets/images/app_logo.webp',
                            width: 30,
                            height: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: Stack(
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    final direction = notification.direction;

                    if (direction == ScrollDirection.forward &&
                        !_isNavVisible) {
                      setState(() {
                        _isNavVisible = true;
                      });
                    } else if (direction == ScrollDirection.reverse &&
                        _isNavVisible) {
                      setState(() {
                        _isNavVisible = false;
                      });
                    }
                    return false;
                  },
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swiping to align with bottom nav paradigm
                    children: pages,
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: 16,
                  right: 16,
                  bottom: (_isNavVisible && !isKeyboardOpen) ? bottomPad : -100,

                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),

                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark.withValues(alpha: 0.97)
                          : AppColors.backgroundLight.withValues(alpha: 0.97),

                      borderRadius: BorderRadius.circular(32),

                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark.withValues(alpha: 0.6)
                            : AppColors.surfaceLight.withValues(alpha: 0.8),
                        width: 1.0,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : AppColors.dividerLight.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                        if (!isDark)
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.9),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: Offset.zero,
                          ),
                      ],
                    ),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,

                        children: [
                          _navItem(0, Icons.home_rounded, 'Home'),

                          _navItem(1, Icons.book_rounded, 'Study'),

                          _navItem(2, Icons.video_library_rounded, 'Tutorials'),

                          if (showEClassroom)
                            _navItem(3, Icons.school_rounded, 'eClassroom'),

                          _navItem(
                            showEClassroom ? 4 : 3,

                            Icons.settings_rounded,

                            'More',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(int index, IconData activeIcon, String label) {
    final theme = Theme.of(context);

    final isActive = _currentIndex == index;

    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? AppColors.primaryDark : AppColors.primary;
    final inactiveColor = activeColor.withValues(alpha: 0.5);
    final currentColor = isActive ? activeColor : inactiveColor;

    final navWidget = GestureDetector(
      onTap: () {
        final user = context.read<AuthProvider>().currentUser;

        if (user == null && index > 0) {
          Navigator.pushNamed(context, '/login');

          return;
        }

        _dismissTutorialShowcase();
        setState(() => _currentIndex = index);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
      },

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),

        // Pill background for active item
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 60,
              padding: EdgeInsets.zero,
              decoration: null,

              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: () {
                  final notificationProvider = context
                      .watch<NotificationProvider>();
                  final unreadNotifs = notificationProvider.notifications
                      .where((n) => !n.isRead)
                      .toList();
                  final hasEClassroomNotification = unreadNotifs.any(
                    (n) =>
                        (n.type == 'grade' ||
                            n.type == 'assignment' ||
                            n.type == 'notice' ||
                            n.type == 'test' ||
                            n.type == 'cbt') &&
                        (n.payload?['centerId'] != null ||
                            n.payload?['adminId'] != null),
                  );

                  final rawIcon = Icon(
                    activeIcon,
                    color: currentColor,
                    size: isActive ? 22 : 18,
                  );

                  if (label == 'eClassroom') {
                    return Badge(
                      key: ValueKey('${index}_$isActive'),
                      isLabelVisible: hasEClassroomNotification && !isActive,
                      smallSize: 8,
                      backgroundColor: Colors.redAccent,
                      child: rawIcon,
                    );
                  }
                  return SizedBox(
                    key: ValueKey('${index}_$isActive'),
                    child: rawIcon,
                  );
                }(),
              ),
            ),

            const SizedBox(height: 3),

            Text(
              label,

              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,

                color: currentColor,

                fontSize: 10,
              ),

              maxLines: 1,

              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    final tutorial = TutorialService.instance;
    if (label == 'Home') {
      return tutorial.buildShowcase(
        key: tutorial.navHomeKey,
        icon: Icons.home_rounded,
        accent: AppColors.primary,
        title: "That's the tour",
        description:
            'Home is always one tap away. You can replay this tour any time from Settings.',
        context: context,
        child: navWidget,
      );
    } else if (label == 'Study') {
      return tutorial.buildShowcase(
        key: tutorial.navStudyKey,
        icon: Icons.menu_book_rounded,
        accent: const Color(0xFF0D9488),
        title: 'Study tab',
        description:
            'Past questions, notes and the simulator live here. Tap Next and we will open it together.',
        context: context,
        child: navWidget,
      );
    } else if (label == 'Tutorials') {
      return tutorial.buildShowcase(
        key: tutorial.navTutorialsKey,
        icon: Icons.play_circle_fill_rounded,
        accent: const Color(0xFF7C3AED),
        title: 'Video lessons',
        description:
            'Prefer to watch a topic explained? Tap Next to see the video tutorials.',
        context: context,
        child: navWidget,
      );
    } else if (label == 'eClassroom') {
      return tutorial.buildShowcase(
        key: tutorial.navEClassroomKey,
        icon: Icons.groups_rounded,
        accent: const Color(0xFF0891B2),
        title: 'eClassroom',
        description:
            'Your centre posts tests and assignments here. Tap Next to take a look.',
        context: context,
        child: navWidget,
      );
    }

    return navWidget;
  }

  void _showChatSheet(BuildContext context) {
    debugPrint('_MainShellState: _showChatSheet called');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final aiProvider = context.watch<AIProvider>();
            final isUserPremium =
                context.read<AuthProvider>().currentUser?.isPremium ?? false;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/images/app_logo.webp',
                                width: 20,
                                height: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cognita AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Always here to help you understand',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (aiProvider.messages.isNotEmpty)
                              IconButton(
                                tooltip: 'Start a new chat',
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_comment_outlined,
                                    size: 18,
                                  ),
                                ),
                                onPressed: () {
                                  aiProvider.clearChat();
                                  setSheetState(() {});
                                },
                              ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    height: 1,
                  ),
                  Expanded(
                    child: aiProvider.messages.isEmpty
                        ? _buildChatWelcome(context, theme)
                        : ListView(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            children: [
                              if (aiProvider.isLoading)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 16.0,
                                    left: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.surfaceDark
                                              : theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                            bottomRight: Radius.circular(20),
                                            bottomLeft: Radius.circular(4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CustomLoader(size: 14),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              "Cognita is thinking...",
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ...aiProvider.messages.map(
                                (msg) => _buildMessageBubble(msg, context),
                              ),
                            ],
                          ),
                  ),
                  Builder(
                    builder: (context) {
                      final media = MediaQuery.of(context);
                      // With the keyboard up the bar rides on the keyboard;
                      // with it down the bar clears the phone's gesture bar,
                      // which otherwise sits over the send button.
                      final bottomGap = media.viewInsets.bottom > 0
                          ? media.viewInsets.bottom + 12
                          : media.viewPadding.bottom + 16;
                      return Container(
                        padding: EdgeInsets.only(
                          bottom: bottomGap,
                          left: 16,
                          right: 16,
                          top: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : theme.scaffoldBackgroundColor,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.05,
                              ),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black26
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.05),
                                  ),
                                ),
                                child: TextField(
                                  controller: controller,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: "Message Cognita...",
                                    hintStyle: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 48,
                              width: 48,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) return;

                                  // Someone typing "faq" wants the help pages, not
                                  // a conversation about them.
                                  if (_isHelpRequest(text)) {
                                    controller.clear();
                                    _openHelpAndFaq(context);
                                    return;
                                  }

                                  aiProvider.sendMessage(
                                    text,
                                    isPremium: isUserPremium,
                                  );
                                  controller.clear();
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Close the sheet and open Settings > Help & FAQ.
  void _openHelpAndFaq(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.pushNamed(AppRoutes.help);
  }

  /// Typed words that mean "show me the help pages".
  bool _isHelpRequest(String text) {
    final asked = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    const asks = {
      'faq',
      'faqs',
      'help',
      'help me',
      'support',
      'guide',
      'guidelines',
      'help and faq',
      'help faq',
      'how to use the app',
      'how to use app',
    };
    return asks.contains(asked);
  }

  /// What Cognita shows before the first question of a conversation.
  Widget _buildChatWelcome(BuildContext context, ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/app_logo.webp',
              width: 50,
              height: 50,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Ask me anything you are studying",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            "Maths, physics, chemistry, English \u2014 type a question, or paste "
            "one you are stuck on, and I will work through it step by step.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 22),
          // Payment, activation and device lock are answered in one place, so
          // this sends readers there instead of repeating them here.
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openHelpAndFaq(context),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Question about the app itself?",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Payment, activation codes and device lock are "
                          "answered in Help & FAQ. Tap here, or type faq, to "
                          "open it.",
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final isAI = !msg.isMe;

    final bubbleColor = msg.isMe
        ? AppColors.primary
        : (isDark
              ? Colors.grey.shade900
              : theme.colorScheme.surfaceContainerHighest);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: Row(
        mainAxisAlignment: msg.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,

        crossAxisAlignment: CrossAxisAlignment.end,

        children: [
          if (isAI) ...[
            Container(
              margin: const EdgeInsets.only(right: 10),

              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),

                shape: BoxShape.circle,
              ),

              child: Image.asset(
                'assets/images/app_logo.webp',

                width: 14,

                height: 14,
              ),
            ),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,

                    vertical: 12,
                  ),

                  decoration: BoxDecoration(
                    color: bubbleColor,

                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),

                      topRight: const Radius.circular(20),

                      bottomLeft: Radius.circular(msg.isMe ? 20 : 4),

                      bottomRight: Radius.circular(msg.isMe ? 4 : 20),
                    ),

                    boxShadow: [
                      if (!msg.isMe && !isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),

                          blurRadius: 5,

                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),

                  // Render the math and text here
                  child: AIMessageRenderer(text: msg.text, isMe: msg.isMe),
                ),

                if (isAI)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),

                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),

                      onTap: () {
                        Clipboard.setData(ClipboardData(text: msg.text));

                        CustomToast.show(
                          context,
                          "Response copied to clipboard!",
                        );
                      },

                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,

                          vertical: 4,
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Icon(
                              Icons.content_copy_rounded,

                              size: 12,

                              color: isDark ? Colors.white54 : Colors.black45,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              "Copy",

                              style: TextStyle(
                                fontSize: 11,

                                color: isDark ? Colors.white54 : Colors.black45,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!msg.isMe &&
                                AIProvider.localFaqs.values.contains(
                                  msg.text,
                                )) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.offline_pin_rounded,
                                size: 12,
                                color: isDark
                                    ? Colors.greenAccent
                                    : Colors.green.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Saved Offline",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.greenAccent
                                      : Colors.green.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
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
}
