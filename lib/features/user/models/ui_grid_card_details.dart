import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class GridCardModel {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? imagePath;
  final Color baseColor;
  final String route;
  final Map<String, dynamic>? arguments;
  final bool requiresNetwork;

  GridCardModel({
    required this.title,
    this.subtitle,
    this.icon,
    this.imagePath,
    required this.baseColor,
    required this.route,
    this.arguments,
    this.requiresNetwork = false,
  });
}

// list of items for home (global quick links)
final List<GridCardModel> homeFeatureList = [
  GridCardModel(
    title: 'Buy Activation Code',
    subtitle: 'Unlock all offline exam simulators',
    icon: Icons.storefront_outlined,
    baseColor: AppColors.dynamicColors[0], // Teal
    route: '/store',
  ),
  GridCardModel(
    title: 'My Orders',
    subtitle: 'View your purchased codes',
    icon: Icons.receipt_long_rounded,
    baseColor: AppColors.dynamicColors[1], // Red
    route: '/purchase',
  ),
  GridCardModel(
    title: 'Admission Finder',
    subtitle: 'Find schools you can get into with your score',
    icon: Icons.school_rounded,
    baseColor: AppColors.dynamicColors[2], // Green
    route: '/admission_finder',
    requiresNetwork: false,
  ),
  GridCardModel(
    title: 'Study Notes',
    subtitle: 'Summarized notes for every subject',
    icon: Icons.menu_book_rounded,
    baseColor: AppColors.dynamicColors[3], // Amber
    route: '/study_notes',
    requiresNetwork: true,
  ),
];

//List of items for More
final List<GridCardModel> moreFeatureList = [
  GridCardModel(
    title: 'My Account',
    subtitle: 'Profile and active device info',
    icon: Icons.person_outline_rounded,
    baseColor: AppColors.dynamicColors[0], // Teal
    route: '/my_account',
  ),
  GridCardModel(
    title: 'Buy Activation Code',
    subtitle: 'Unlock all offline exam simulators',
    icon: Icons.storefront_outlined,
    baseColor: AppColors.dynamicColors[4], // Purple
    route: '/store',
  ),
  GridCardModel(
    title: 'Settings',
    subtitle: 'App preferences and modes',
    icon: Icons.settings_outlined,
    baseColor: AppColors.dynamicColors[1], // Red
    route: '/settings',
  ),
  GridCardModel(
    title: 'Study Notes',
    subtitle: 'Summarized notes for every subject',
    icon: Icons.menu_book_rounded,
    baseColor: AppColors.dynamicColors[2], // Coral
    route: '/study_notes',
    requiresNetwork: true,
  ),
  GridCardModel(
    title: 'Announcements',
    subtitle: 'Stay updated with latest news',
    icon: Icons.campaign_outlined,
    baseColor: AppColors.dynamicColors[3], // Amber
    route: '/announcements',
    requiresNetwork: true,
  ),
];

// =========================================================================
// EXAM DASHBOARD ITEMS
// =========================================================================

/// Dashboard items for standard exams: JAMB, WAEC, NECO
/// Includes: Bookmark, Simulator, History, Performance Analysis, Syllabus, Brochure
/// Study notes are no longer here: they are a single global list, reached from
/// the Home and More quick links.
List<GridCardModel> standardExamDashboardItems(String examType) {
  // Map examType to syllabus route keys
  final syllabusExamType = _syllabusKeyFor(examType);
  final brochureExamType = _brochureKeyFor(examType);
  final examLabel = examType.toLowerCase() == 'jamb'
      ? 'JAMB UTME'
      : examType.toUpperCase();

  final isJamb = examType.toLowerCase() == 'jamb';

  return [
    GridCardModel(
      title: 'Simulator',
      subtitle: 'Practice timed CBT exam sessions offline',
      icon: Icons.computer_rounded,
      baseColor: AppColors.dynamicColors[0], // Teal
      route: '/exam_simulator_entry',
      arguments: {'examType': examType},
    ),
    GridCardModel(
      title: 'Result\nHistory',
      subtitle: 'Review past simulator scores',
      icon: Icons.history_rounded,
      baseColor: AppColors.dynamicColors[3], // Amber
      route: '/utme_history',
      arguments: {'examType': examType},
    ),
    GridCardModel(
      title: 'Performance\nAnalysis',
      subtitle: 'Analytics and weakness tracking',
      icon: Icons.insights_rounded,
      baseColor: AppColors.dynamicColors[5], // Pink
      route: '/performance_analysis',
      arguments: {'examType': examType},
    ),
    if (!isJamb)
      GridCardModel(
        title: '$examLabel\nSyllabus',
        subtitle: 'Study official syllabus and topics',
        icon: Icons.assignment_outlined,
        baseColor: AppColors.dynamicColors[1], // Red
        route: '/exam_syllabus',
        arguments: {
          'examType': syllabusExamType,
          'title': '$examLabel Syllabus',
        },
        requiresNetwork: true,
      ),
    if (!isJamb)
      GridCardModel(
        title: '$examLabel\nBrochure',
        subtitle: 'Check course guidelines and cutoffs',
        icon: Icons.account_balance_outlined,
        baseColor: AppColors.dynamicColors[3], // Amber
        route: '/exam_syllabus',
        arguments: {
          'examType': brochureExamType,
          'title': '$examLabel Brochure',
        },
        requiresNetwork: true,
      ),

    GridCardModel(
      title: 'Bookmark',
      subtitle: 'Review saved practice questions',
      icon: Icons.bookmark_outline_rounded,
      baseColor: AppColors.dynamicColors[2], // Green
      route: '/bookmarked',
      arguments: {'examType': examType},
    ),
  ];
}

/// Dashboard items for Post-UTME exams (institution-specific)
/// Includes: Bookmark, Simulator, History, Performance Analysis, Institution Brochure
List<GridCardModel> postUtmeDashboardItems(
  String examType,
  String institutionId,
  String institutionName,
  String? logoUrl, {
  String? sectionId,
}) {
  return [
    GridCardModel(
      title: 'Simulator',
      subtitle: 'Practice school CBT screening',
      icon: Icons.computer_rounded,
      baseColor: AppColors.dynamicColors[0], // Teal
      route: '/exam_simulator_entry',
      arguments: {
        'examType': examType,
        'institutionId': institutionId,
        'institutionName': institutionName,
        'logoUrl': logoUrl,
        'sectionId': sectionId,
      },
    ),
    GridCardModel(
      title: 'Result\nHistory',
      subtitle: 'Review past screening scores',
      icon: Icons.history_rounded,
      baseColor: AppColors.dynamicColors[3], // Amber
      route: '/utme_history',
      arguments: {
        'examType': examType,
        'schoolId': institutionId,
        'institutionId': institutionId,
        'sectionId': sectionId,
      },
    ),
    GridCardModel(
      title: 'Performance\nAnalysis',
      subtitle: 'Analyze your screening readiness',
      icon: Icons.insights_rounded,
      baseColor: AppColors.dynamicColors[5], // Pink
      route: '/performance_analysis',
      arguments: {
        'examType': examType,
        'schoolId': institutionId,
        'institutionId': institutionId,
        'sectionId': sectionId,
      },
    ),
    GridCardModel(
      title: 'Admission\nGuideline',
      subtitle: 'Check screening instructions',
      icon: Icons.account_balance_outlined,
      baseColor: AppColors.dynamicColors[1], // Red
      route: '/admission-guideline',
      arguments: {
        'examType': 'post_utme_admission_guideline',
        'title': 'Admission Guideline',
        'schoolId': institutionId,
        'institutionId': institutionId,
        'sectionId': sectionId,
      },
    ),
    GridCardModel(
      title: 'Bookmark',
      subtitle: 'Review saved screening questions',
      icon: Icons.bookmark_outline_rounded,
      baseColor: AppColors.dynamicColors[2], // Green
      route: '/bookmarked',
      arguments: {
        'examType': examType,
        'schoolId': institutionId,
        'institutionId': institutionId,
        'sectionId': sectionId,
      },
    ),
  ];
}

// =========================================================================
// HELPERS
// =========================================================================

String _syllabusKeyFor(String examType) {
  switch (examType.toLowerCase()) {
    case 'jamb':
      return 'jamb_s';
    case 'waec':
      return 'waec';
    case 'neco':
      return 'neco';
    default:
      return examType;
  }
}

String _brochureKeyFor(String examType) {
  switch (examType.toLowerCase()) {
    case 'jamb':
      return 'jamb_b';
    case 'waec':
      return 'waec_b';
    case 'neco':
      return 'neco_b';
    default:
      return '${examType}_b';
  }
}
