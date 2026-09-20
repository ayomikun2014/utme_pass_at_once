import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/user/utils/main_shell.dart';
import '../constants/app_colors.dart';

/// The guided tour of the app.
///
/// Each stop points at one real control and explains it in the reader's own
/// words. The card carries the same icon and colour as the thing it is
/// pointing at, says how far along the tour is, and lets the reader step back
/// as well as forward.
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

  /// Whether this reader belongs to a centre, which adds the eClassroom stops.
  bool _hasEClassroom = false;

  /// Every stop in order, so each card can say "3 of 10".
  List<GlobalKey> get _allSteps => [
    welcomeKey,
    notificationKey,
    settingsKey,
    examSliderKey,
    quickLinksKey,
    navStudyKey,
    studyExamCardKey,
    navTutorialsKey,
    tutorialTrackKey,
    tutorialSearchKey,
    if (_hasEClassroom) ...[navEClassroomKey, eclassroomCentersKey, navHomeKey],
  ];

  /// The first stop of each tab, where there is nothing to step back to.
  bool _isPhaseStart(GlobalKey key) =>
      key == welcomeKey ||
      key == studyExamCardKey ||
      key == tutorialTrackKey ||
      key == eclassroomCentersKey;

  bool _isLastStep(GlobalKey key) =>
      _hasEClassroom ? key == navHomeKey : key == tutorialSearchKey;

  bool _showEClassroomFor(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    return user != null &&
        user.referredBy != null &&
        user.referredBy!.isNotEmpty &&
        user.referredBy != '--';
  }

  /// Check if the tutorial needs to be shown based on login and version update
  Future<void> checkAndShowTutorial(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return; // Only show for logged in users

    try {
      final prefs = await SharedPreferences.getInstance();
      final String userKey = 'tutorial_completed_${user.uid}';
      final bool completed =
          prefs.getBool(userKey) ??
          prefs.getBool('tutorial_completed') ??
          false;

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
    _hasEClassroom = _showEClassroomFor(context);

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
          ShowCaseWidget.of(
            activeContext,
          ).startShowCase([studyExamCardKey, navTutorialsKey]);
        }
      });
    });
  }

  /// Transition: Study -> Tutorials Tab
  void transitionToTutorialsTab(BuildContext context) {
    final activeContext = showcaseContext ?? context;
    ShowCaseWidget.of(activeContext).dismiss();
    MainShell.switchTab(2);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (activeContext.mounted) {
          ShowCaseWidget.of(activeContext).startShowCase([
            tutorialTrackKey,
            tutorialSearchKey,
            if (_hasEClassroom) navEClassroomKey,
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
          ShowCaseWidget.of(
            activeContext,
          ).startShowCase([eclassroomCentersKey, navHomeKey]);
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
      final String currentVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

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
      final String currentVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

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

  /// Wrap a control in a tour stop.
  ///
  /// [icon] and [accent] should be the control's own icon and colour, so the
  /// card reads as an extension of what it is pointing at.
  Widget buildShowcase({
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
    required BuildContext context,
    IconData icon = Icons.lightbulb_rounded,
    Color? accent,
    bool isCircleBorder = false,
  }) {
    final steps = _allSteps;
    final index = steps.indexOf(key);
    final isLast = _isLastStep(key);
    final colour = accent ?? AppColors.primary;
    final size = _cardSize(context, title, description);

    return Showcase.withWidget(
      key: key,
      height: size.height,
      width: size.width,
      targetPadding: const EdgeInsets.all(6),
      targetShapeBorder: isCircleBorder
          ? const CircleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      overlayOpacity: 0.78,
      container: _TourCard(
        title: title,
        description: description,
        icon: icon,
        accent: colour,
        width: size.width,
        step: index < 0 ? 1 : index + 1,
        total: steps.length,
        canGoBack: !_isPhaseStart(key),
        isLast: isLast,
        onSkip: () => skipTutorial(context),
        onBack: () => ShowCaseWidget.of(context).previous(),
        onNext: () {
          if (key == navStudyKey) {
            transitionToStudyTab(context);
          } else if (key == navTutorialsKey) {
            transitionToTutorialsTab(context);
          } else if (key == navEClassroomKey) {
            transitionToEClassroomTab(context);
          } else if (isLast) {
            completeTutorial(context);
          } else {
            ShowCaseWidget.of(context).next();
          }
        },
      ),
      child: child,
    );
  }

  /// The card is laid out by hand, so its size has to be worked out before it
  /// is shown -- otherwise long wording is cut off mid-sentence.
  Size _cardSize(BuildContext context, String title, String description) {
    final media = MediaQuery.of(context);
    final width = (media.size.width - 48).clamp(240.0, 330.0);
    final textWidth = width - 32;

    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: media.textScaler,
      )..layout(maxWidth: textWidth);
      return painter.height;
    }

    final titleHeight = measure(
      title,
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
    );
    final bodyHeight = measure(
      description,
      const TextStyle(fontSize: 13.5, height: 1.45),
    );

    // padding + icon row + progress + title + body + buttons, plus a little
    // slack so a larger system font never clips the card.
    final height =
        16 +
        34 +
        12 +
        6 +
        14 +
        titleHeight +
        8 +
        bodyHeight +
        16 +
        40 +
        16 +
        10;
    return Size(width, height);
  }
}

/// One stop on the tour.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.width,
    required this.step,
    required this.total,
    required this.canGoBack,
    required this.isLast,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final double width;
  final int step;
  final int total;
  final bool canGoBack;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The feature's own icon, and how far along the tour is.
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.24 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: accent),
                ),
                const Spacer(),
                Text(
                  'Step $step of $total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress so far.
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : step / total,
                minHeight: 6,
                backgroundColor: onSurface.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.5),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const Spacer(),
                if (canGoBack)
                  TextButton.icon(
                    onPressed: onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: onSurface.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 15),
                    label: const Text(
                      'Back',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(64, 36),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 15,
                  ),
                  label: Text(
                    isLast ? 'Finish' : 'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
