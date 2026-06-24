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

  StreamSubscription<QuerySnapshot>? _notifSubscription;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAppLaunchChecks();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();

    _notifSubscription?.cancel();

    super.dispose();
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

  void _switchTo(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomPad = isKeyboardOpen ? -90.0 : 16.0;

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
              setState(() {
                _currentIndex = 0;
                _isNavVisible = true;
              });
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                );
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
            floatingActionButton: null,
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
                  left: 20,
                  right: 20,
                  bottom: (_isNavVisible && !isKeyboardOpen) ? bottomPad : -90,

                  child: Container(
                    height: 65,

                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark.withValues(alpha: 0.95)
                          : AppColors.backgroundLight.withValues(alpha: 0.95),

                      borderRadius: BorderRadius.circular(24),

                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.surfaceLight,
                      ),

                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: AppColors.dividerLight.withValues(
                              alpha: 0.5,
                            ),

                            blurRadius: 10,

                            offset: const Offset(0, 8),
                          ),
                      ],
                    ),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,

                        children: [
                          _navItem(
                            0,

                            Icons.home_rounded,

                            'Home',
                          ),

                          _navItem(
                            1,

                            Icons.book_rounded,

                            'Study',
                          ),

                          _navItem(
                            2,

                            Icons.video_library_rounded,

                            'Tutorials',
                          ),

                          if (showEClassroom)
                            _navItem(
                              3,

                              Icons.school_rounded,

                              'eClassroom',
                            ),

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

  Widget _navItem(
    int index,

    IconData activeIcon,

    String label,
  ) {
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

        setState(() => _currentIndex = index);
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        }
      },

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),

        width: 60,

        child: Column(
          mainAxisSize: MainAxisSize.min,

          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 20 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 4),

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

            const SizedBox(height: 2),

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
        title: 'All Caught Up! 🏁',
        description:
            'You are ready to crush your exams! Tap "Done" to finish the tour.',
        context: context,
        child: navWidget,
      );
    } else if (label == 'Study') {
      return tutorial.buildShowcase(
        key: tutorial.navStudyKey,
        title: 'Study Hub 📚',
        description:
            "Let's check out the Study tab for detailed study materials and simulators. Tapping next will take you there!",
        context: context,
        child: navWidget,
      );
    } else if (label == 'Tutorials') {
      return tutorial.buildShowcase(
        key: tutorial.navTutorialsKey,
        title: 'Video Tutorials 🎬',
        description:
            'Need visual explanations? Tapping next will open the Video Tutorials tab!',
        context: context,
        child: navWidget,
      );
    } else if (label == 'eClassroom') {
      return tutorial.buildShowcase(
        key: tutorial.navEClassroomKey,
        title: 'eClassroom Portal 🏫',
        description:
            'If you belong to an affiliated center, tap next to visit your interactive classroom center.',
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

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {
        final aiProvider = context.watch<AIProvider>();

        final isUserPremium =
            context.read<AuthProvider>().currentUser?.isPremium ?? false;

        final TextEditingController controller = TextEditingController();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,

          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : theme.scaffoldBackgroundColor,

            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),

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
                            color: AppColors.primary.withValues(alpha: 0.15),

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

                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),

                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),

                          shape: BoxShape.circle,
                        ),

                        child: const Icon(Icons.close_rounded, size: 20),
                      ),

                      onPressed: () => Navigator.pop(context),
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
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),

                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),

                                  shape: BoxShape.circle,
                                ),

                                child: Image.asset(
                                  'assets/images/app_logo.webp',

                                  width: 80,

                                  height: 80,
                                ),
                              ),

                              const SizedBox(height: 24),

                              const Text(
                                "Ask Me Anything!",

                                style: TextStyle(
                                  fontWeight: FontWeight.w900,

                                  fontSize: 22,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Text(
                                "I can explain difficult topics,\nsolve equations, or give study tips.",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  fontSize: 15,

                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),

                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 30),

                              Wrap(
                                spacing: 10,

                                runSpacing: 10,

                                alignment: WrapAlignment.center,

                                children: [
                                  _buildSuggestionChip(
                                    "Explain Osmosis",

                                    aiProvider,

                                    isUserPremium,
                                  ),

                                  _buildSuggestionChip(
                                    "Solve for x",

                                    aiProvider,

                                    isUserPremium,
                                  ),

                                  _buildSuggestionChip(
                                    "Exam tips",

                                    aiProvider,

                                    isUserPremium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        reverse: true,

                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,

                          vertical: 20,
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

              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,

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
                              : theme.colorScheme.surfaceContainerHighest,

                          borderRadius: BorderRadius.circular(24),

                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),

                        child: TextField(
                          controller: controller,

                          minLines: 1,

                          maxLines: 4,

                          textCapitalization: TextCapitalization.sentences,

                          style: const TextStyle(fontSize: 15),

                          decoration: InputDecoration(
                            hintText: "Message Cognita...",

                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
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
                          if (controller.text.trim().isNotEmpty) {
                            aiProvider.sendMessage(
                              controller.text.trim(),

                              isPremium: isUserPremium,
                            );

                            controller.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChip(
    String text,

    AIProvider aiProvider,

    bool isUserPremium,
  ) {
    return ActionChip(
      label: Text(
        text,

        style: const TextStyle(
          fontSize: 13,

          fontWeight: FontWeight.w600,

          color: AppColors.primary,
        ),
      ),

      backgroundColor: AppColors.primary.withValues(alpha: 0.08),

      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      onPressed: () {
        aiProvider.sendMessage(text, isPremium: isUserPremium);
      },
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
