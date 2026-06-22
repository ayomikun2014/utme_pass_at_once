import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/user/utils/main_shell.dart';
import '../constants/app_colors.dart';

class TutorialService {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  /// Stable BuildContext underneath ShowCaseWidget, set by MainShell
  BuildContext? showcaseContext;

  // --- HOME TAB KEYS ---
  final GlobalKey welcomeKey = GlobalKey();
  final GlobalKey notificationKey = GlobalKey();
  final GlobalKey settingsKey = GlobalKey();
  final GlobalKey examSliderKey = GlobalKey();
  final GlobalKey quickLinksKey = GlobalKey();
  final GlobalKey newsKey = GlobalKey();

  // --- STUDY TAB KEYS ---
  final GlobalKey studyExamCardKey = GlobalKey();

  // --- TUTORIALS TAB KEYS ---
  final GlobalKey tutorialTrackKey = GlobalKey();
  final GlobalKey tutorialSearchKey = GlobalKey();

  // --- ECLASSROOM TAB KEYS ---
  final GlobalKey eclassroomCentersKey = GlobalKey();

  // --- BOTTOM NAV BAR KEYS ---
  final GlobalKey navHomeKey = GlobalKey();
  final GlobalKey navStudyKey = GlobalKey();
  final GlobalKey navTutorialsKey = GlobalKey();
  final GlobalKey navEClassroomKey = GlobalKey();

  // Active status of showcase
  bool isTutorialActive = false;

  /// Check if the tutorial needs to be shown based on login and version update
  Future<void> checkAndShowTutorial(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return; // Only show for logged in users

    try {
      final prefs = await SharedPreferences.getInstance();
      final String userKey = 'tutorial_completed_${user.uid}';
      final bool completed = prefs.getBool(userKey) ?? prefs.getBool('tutorial_completed') ?? false;

      // Auto-trigger if not completed
      if (!completed) {
        // Wait a small delay after screen mounts before triggering
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (context.mounted) {
              startTutorial(context);
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
    }
  }

  /// Start the onboarding tutorial flow from Phase 1 (Home tab)
  void startTutorial(BuildContext context, {bool force = false}) {
    if (isTutorialActive && !force) return;
    isTutorialActive = true;

    // Reset navigation shell to Home page first
    MainShell.switchTab(0);

    final activeContext = showcaseContext ?? context;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (activeContext.mounted) {
          ShowCaseWidget.of(activeContext).startShowCase([
            welcomeKey,
            notificationKey,
            settingsKey,
            examSliderKey,
            quickLinksKey,
            navStudyKey,
          ]);
        }
      });
    });
  }

  /// Transition: Home -> Study Tab
  void transitionToStudyTab(BuildContext context) {
    final activeContext = showcaseContext ?? context;
    ShowCaseWidget.of(activeContext).dismiss();
    MainShell.switchTab(1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (activeContext.mounted) {
          ShowCaseWidget.of(activeContext).startShowCase([
            studyExamCardKey,
            navTutorialsKey,
          ]);
        }
      });
    });
  }

  /// Transition: Study -> Tutorials Tab
  void transitionToTutorialsTab(BuildContext context) {
    final activeContext = showcaseContext ?? context;
    ShowCaseWidget.of(activeContext).dismiss();
    MainShell.switchTab(2);

    final authProvider = activeContext.read<AuthProvider>();
    final user = authProvider.currentUser;
    final showEClassroom = user != null &&
        user.referredBy != null &&
        user.referredBy!.isNotEmpty &&
        user.referredBy != '--';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (activeContext.mounted) {
          ShowCaseWidget.of(activeContext).startShowCase([
            tutorialTrackKey,
            tutorialSearchKey,
            if (showEClassroom) navEClassroomKey,
          ]);
        }
      });
    });
  }

  /// Transition: Tutorials -> eClassroom Tab
  void transitionToEClassroomTab(BuildContext context) {
    final activeContext = showcaseContext ?? context;
    ShowCaseWidget.of(activeContext).dismiss();
    MainShell.switchTab(3);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (activeContext.mounted) {
          ShowCaseWidget.of(activeContext).startShowCase([
            eclassroomCentersKey,
            navHomeKey,
          ]);
        }
      });
    });
  }

  /// Clean up and finish the tutorial
  Future<void> completeTutorial(BuildContext context) async {
    isTutorialActive = false;
    final activeContext = showcaseContext ?? context;
    final auth = context.read<AuthProvider>();
    try {
      ShowCaseWidget.of(activeContext).dismiss();
    } catch (_) {}
    MainShell.switchTab(0); // Go back home

    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final user = auth.currentUser;
      if (user != null) {
        await prefs.setBool('tutorial_completed_${user.uid}', true);
      }
      await prefs.setBool('tutorial_completed', true);
      await prefs.setString('tutorial_app_version', currentVersion);
    } catch (e) {
      debugPrint('Error saving tutorial completion: $e');
    }
  }

  /// Skip the tutorial entirely
  Future<void> skipTutorial(BuildContext context) async {
    isTutorialActive = false;
    final activeContext = showcaseContext ?? context;
    final auth = context.read<AuthProvider>();
    try {
      ShowCaseWidget.of(activeContext).dismiss();
    } catch (_) {}
    MainShell.switchTab(0);

    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final user = auth.currentUser;
      if (user != null) {
        await prefs.setBool('tutorial_completed_${user.uid}', true);
      }
      await prefs.setBool('tutorial_completed', true);
      await prefs.setString('tutorial_app_version', currentVersion);
    } catch (e) {
      debugPrint('Error saving tutorial skip state: $e');
    }
  }

  /// Builds a standard custom tooltip wrapper
  Widget buildShowcase({
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
    required BuildContext context,
    bool isCircleBorder = false,
  }) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final showEClassroom = user != null &&
        user.referredBy != null &&
        user.referredBy!.isNotEmpty &&
        user.referredBy != '--';

    return Showcase.withWidget(
      key: key,
      height: 180,
      width: 290,
      targetShapeBorder: isCircleBorder ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      container: CustomShowcaseTooltip(
        title: title,
        description: description,
        onSkip: () => skipTutorial(context),
        onNext: () {
          if (key == navStudyKey) {
            transitionToStudyTab(context);
          } else if (key == navTutorialsKey) {
            transitionToTutorialsTab(context);
          } else if (key == navEClassroomKey) {
            transitionToEClassroomTab(context);
          } else if (key == navHomeKey || (key == tutorialSearchKey && !showEClassroom)) {
            completeTutorial(context);
          } else {
            ShowCaseWidget.of(context).next();
          }
        },
        isLast: key == navHomeKey || (key == tutorialSearchKey && !showEClassroom),
      ),
      child: child,
    );
  }
}

class CustomShowcaseTooltip extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const CustomShowcaseTooltip({
    super.key,
    required this.title,
    required this.description,
    required this.onNext,
    required this.onSkip,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Title with Accent Bar
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip Button
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Skip Tour',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              // Next / Done Button
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLast ? 'Done' : 'Next',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
