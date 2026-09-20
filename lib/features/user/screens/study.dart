import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/bg.dart';
import '../../../core/utils/custom_app_bar.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/simulator_provider.dart';
import '../utils/activation_bottom_sheet.dart';
import '../../../core/services/tutorial_service.dart';

class Study extends StatelessWidget {
  const Study({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          AnimationLimiter(
            child: CustomScrollView(
              slivers: [
                CustomAppBar(
                  title: 'Study',
                  subtitle:
                  'Choose your exam type to access tools and resources.',
                  color: AppColors.dynamicColors[4].withValues(alpha: 0.9),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final exam = _examTypes[index];
                      final bool isComingSoon = exam['isComingSoon'] as bool? ?? false;

                      Widget card = _ExamCard(
                        title: exam['title'] as String,
                        subtitle: exam['subtitle'] as String,
                        logo: exam['logo'] as String,
                        gradientColors:
                        exam['gradientColors'] as List<Color>,
                        isComingSoon: isComingSoon,
                        onTap: isComingSoon
                            ? () => _showLocked(
                          context,
                          '${exam['title']} Preparation coming soon!',
                        )
                            : () => _onExamTap(
                          context,
                          exam['examType'] as String,
                        ),
                      );

                      if (index == 0) {
                        card = TutorialService.instance.buildShowcase(
                          key: TutorialService.instance.studyExamCardKey,
                          icon: Icons.menu_book_rounded,
                          accent: AppColors.primary,
                          title: 'Everything for one exam',
                          description: 'Open an exam to find its past questions, syllabus, summarised notes and the CBT simulator in one place.',
                          context: context,
                          child: card,
                        );
                      }

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 600),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: card,
                          ),
                        ),
                      );
                    }, childCount: _examTypes.length),
                  ),
                ),
                // Bottom padding for floating nav bar
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _onExamTap(BuildContext context, String examType) async {
    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      _showLocked(context, 'Please login to access this feature');
      return;
    }

    final isPremiumOnThisDevice = authProvider.hasPremiumAccessFor(examType);
    final isPremiumAnyDevice = authProvider.hasPremiumAnyDevice(examType);

    // CASE 1: Premium on another device, NOT this device
    if (isPremiumAnyDevice && !isPremiumOnThisDevice) {
      if (context.mounted) _showDeviceMismatchDialog(context, examType);
      return;
    }

    // CASE 2: Premium on THIS device — check if offline data is downloaded
    if (isPremiumOnThisDevice) {
      final activatedCenters = user.getExamCenters(examType);

      if (activatedCenters.isNotEmpty) {
        bool hasMissingPackage = false;
        String missingInstitutionId = '';
        String? missingSectionId;

        for (final institutionKey in activatedCenters) {
          // Use getSectionForInstitution for consistent sectionId with update.dart
          final section = user.getSectionForInstitution(examType, institutionKey);
          final sectionId = section?['id'];

          final baseInstitutionId = examType == 'post_utme' && institutionKey.contains('_')
              ? institutionKey.split('_').first
              : institutionKey;

          final downloaded = await simProvider.isActivatedPackageDownloaded(
            examType: examType,
            institutionId: baseInstitutionId,
            sectionId: sectionId,
          );

          if (!downloaded) {
            hasMissingPackage = true;
            missingInstitutionId = baseInstitutionId;
            missingSectionId = sectionId;
            break;
          }
        }

        // If offline data is missing, prompt the user to download it
        if (hasMissingPackage && context.mounted) {
          _showMissingDataDialog(
            context,
            examType,
            missingInstitutionId,
            sectionId: missingSectionId,
          );
          return;
        }
      }
    }

    if (!context.mounted) return;

    if (examType == 'post_utme') {
      Navigator.pushNamed(context, '/institution_selection');
    } else {
      Navigator.pushNamed(
        context,
        '/exam_dashboard',
        arguments: {'examType': examType},
      );
    }
  }

  /// Directly shows the ActivationBottomSheet and downloads missing data.
  /// No network gate — the download itself will fail gracefully if offline.
  void _autoDownloadAndNavigate(
      BuildContext context,
      String examType,
      String institutionId, {
        String? sectionId,
      }) {
    final provider = context.read<SimulatorProvider>();
    // The package records which subjects were bought; only those are fetched.
    final user = context.read<AuthProvider>().currentUser;
    final centerKey = (sectionId != null && sectionId.trim().isNotEmpty)
        ? '${institutionId.toLowerCase()}_${sectionId.toLowerCase()}'
        : institutionId.toLowerCase();

    final downloadFuture = provider.downloadActivationData(
      examType: examType,
      institutionId: institutionId,
      subjects: user?.getSubjectsForCenter(examType, centerKey),
      sectionId: sectionId,
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ActivationBottomSheet(
        task: () => downloadFuture,
        onComplete: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              // Navigate directly to the next screen!
              if (examType == 'post_utme') {
                Navigator.pushNamed(context, '/institution_selection');
              } else {
                Navigator.pushNamed(
                  context,
                  '/exam_dashboard',
                  arguments: {'examType': examType},
                );
              }
            }
          });
        },
      ),
    );
  }

  void _showMissingDataDialog(
      BuildContext context,
      String examType,
      String institutionId, {
        String? sectionId,
      }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cloud_download_outlined,
                color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Missing Offline Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your premium exam data is incomplete or missing from this device. '
              'This usually happens if you cleared your app cache, or if a previous download was interrupted.\n\n'
              'Would you like to restore your offline data now?',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close the dialog
              // Trigger the actual download
              _autoDownloadAndNavigate(
                context,
                examType,
                institutionId,
                sectionId: sectionId,
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  void _showDeviceMismatchDialog(BuildContext context, String examType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.phonelink_off_rounded,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Different Device',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your premium access for this exam was activated on a different device. '
              'To access premium content on this device, you\'ll need a new activation code.\n\n'
              'You can also try the free version with limited questions.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // Free Trial button
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate as a FREE user (isPremium = false)
              if (examType == 'post_utme') {
                Navigator.pushNamed(context, '/institution_selection');
              } else {
                Navigator.pushNamed(
                  context,
                  '/exam_dashboard',
                  arguments: {'examType': examType},
                );
              }
            },
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Free Trial'),
          ),
          // Buy Again button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/store');
            },
            icon: const Icon(Icons.shopping_cart_rounded, size: 18),
            label: const Text('Buy Again'),
          ),
        ],
      ),
    );
  }

  void _showLocked(BuildContext context, String message) {
    CustomToast.show(context, message);
  }
}

// =========================================================================
// EXAM TYPE DATA
// =========================================================================

final List<Map<String, dynamic>> _examTypes = [
  {
    'title': 'Post-UTME',
    'subtitle': 'Institution-specific past questions & resources.',
    'logo': 'assets/images/post_utme.webp',
    'examType': 'post_utme',
    'isComingSoon': false,
    'gradientColors': [const Color(0xFF7C3AED), const Color(0xFF4F46E5)], // Royal Purple to Deep Indigo
  },
  {
    'title': 'JAMB UTME',
    'subtitle': 'UTME past questions, syllabus, brochure & simulator.',
    'logo': 'assets/images/jamb.webp',
    'examType': 'jamb',
    'isComingSoon': false,
    'gradientColors': [const Color(0xFF0D9488), const Color(0xFF0F766E)], // Sea Mint to Deep Teal
  },
  {
    'title': 'WAEC',
    'subtitle': 'SSCE past questions, syllabus & practice exams.',
    'logo': 'assets/images/waec.webp',
    'examType': 'waec',
    'isComingSoon': true,
    'gradientColors': [const Color(0xFFF43F5E), const Color(0xFFE11D48)], // Sunset Coral to Rose Red
  },
  {
    'title': 'NECO',
    'subtitle': 'SSCE past questions, syllabus & practice exams.',
    'logo': 'assets/images/neco.webp',
    'examType': 'neco',
    'isComingSoon': true,
    'gradientColors': [const Color(0xFF2563EB), const Color(0xFF1D4ED8)], // Sapphire Blue to Deep Cobalt
  },
];

// =========================================================================
// EXAM CARD WIDGET
// =========================================================================

class _ExamCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String logo;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool isComingSoon;

  const _ExamCard({
    required this.title,
    required this.subtitle,
    required this.logo,
    required this.gradientColors,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool dimmed = widget.isComingSoon;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(minHeight: 120),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dimmed
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : widget.gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: dimmed
                ? []
                : [
                    BoxShadow(
                      color: widget.gradientColors[0].withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned(
                top: -25,
                right: -25,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(widget.logo, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (dimmed) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'COMING SOON',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        dimmed
                            ? Icons.lock_outline_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}