import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class GridCardModel {
  final String title;
  final IconData? icon;
  final String? imagePath;
  final Color baseColor;
  final String route;
  final Map<String, dynamic>? arguments;
  final bool requiresNetwork;

  GridCardModel({
    required this.title,
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
    title: 'Store',
    icon: Icons.storefront_outlined,
    baseColor: AppColors.dynamicColors[0], // Teal
    route: '/store',
  ),
  GridCardModel(
    title: 'My Purchases',
    icon: Icons.receipt_long_rounded,
    baseColor: AppColors.dynamicColors[1], // Red
    route: '/purchase',
  ),
  GridCardModel(
    title: 'Cognita AI',
    imagePath: 'assets/images/app_logo.webp',
    baseColor: AppColors.dynamicColors[2], // Green
    route: '/ai_chat',
  ),
  GridCardModel(
    title: 'Announcements',
    icon: Icons.campaign_outlined,
    baseColor: AppColors.dynamicColors[3], // Amber
    route: '/announcements',
    requiresNetwork: true,
  ),
];

//List of items for More
final List<GridCardModel> moreFeatureList = [
  GridCardModel(
    title: 'My Account',
    icon: Icons.person_outline_rounded,
    baseColor: AppColors.dynamicColors[0], // Teal
    route: '/my_account',
  ),
  GridCardModel(
    title: 'Store',
    icon: Icons.storefront_outlined,
    baseColor: AppColors.dynamicColors[4], // Purple
    route: '/store',
  ),
  GridCardModel(
    title: 'Settings',
    icon: Icons.settings_outlined,
    baseColor: AppColors.dynamicColors[1], // Red
    route: '/settings',
  ),
  GridCardModel(
    title: 'Announcements',
    icon: Icons.campaign_outlined,
    baseColor: AppColors.dynamicColors[2], // Coral
    route: '/announcements',
    requiresNetwork: true,
  ),
];

// =========================================================================
// EXAM DASHBOARD ITEMS
// =========================================================================

/// Dashboard items for standard exams: JAMB, WAEC, NECO
/// Includes: Bookmark, Simulator, History, Performance Analysis, Study Notes, Syllabus, Brochure
List<GridCardModel> standardExamDashboardItems(String examType) {
  // Map examType to syllabus route keys
  final syllabusExamType = _syllabusKeyFor(examType);
  final brochureExamType = _brochureKeyFor(examType);
  final examLabel = examType.toLowerCase() == 'jamb' ? 'JAMB UTME' : examType.toUpperCase();

  return [
    GridCardModel(
      title: 'Bookmark',
      icon: Icons.bookmark_outline_rounded,
      baseColor: AppColors.dynamicColors[2], // Green
      route: '/bookmarked',
      arguments: {'examType': examType},
    ),
    GridCardModel(
      title: 'Simulator',
      icon: Icons.computer_rounded,
      baseColor: AppColors.dynamicColors[0], // Teal
      route: '/exam_simulator_entry',
      arguments: {'examType': examType},
    ),
    GridCardModel(
      title: 'Result\nHistory',
      icon: Icons.history_rounded,
      baseColor: AppColors.dynamicColors[3], // Amber
      route: '/utme_history',
      arguments: {'examType': examType},
    ),
    GridCardModel(
      title: 'Performance\nAnalysis',
      icon: Icons.insights_rounded,
      baseColor: AppColors.dynamicColors[5], // Pink
      route: '/performance_analysis',
      arguments: {'examType': examType},
      requiresNetwork: true,
    ),
    GridCardModel(
      title: 'Study\nNotes',
      icon: Icons.menu_book_rounded,
      baseColor: AppColors.dynamicColors[4], // Purple
      route: '/study_notes',
      arguments: {'examType': examType},
      requiresNetwork: true,
    ),
    GridCardModel(
      title: '$examLabel\nSyllabus',
      icon: Icons.assignment_outlined,
      baseColor: AppColors.dynamicColors[1], // Red
      route: '/exam_syllabus',
      arguments: {'examType': syllabusExamType, 'title': '$examLabel Syllabus'},
      requiresNetwork: true,
    ),
    GridCardModel(
      title: '$examLabel\nBrochure',
      icon: Icons.account_balance_outlined,
      baseColor: AppColors.dynamicColors[3], // Amber
      route: '/exam_syllabus',
      arguments: {
        'examType': brochureExamType,
        'title': '$examLabel Brochure',
      },
      requiresNetwork: true,
    ),
  ];
}

/// Dashboard items for Post-UTME exams (institution-specific)
/// Includes: Bookmark, Simulator, History, Performance Analysis, Study Notes, Institution Brochure
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
      title: 'Study\nNotes',
      icon: Icons.menu_book_rounded,
      baseColor: AppColors.dynamicColors[4], // Purple
      route: '/study_notes',
      arguments: {
        'examType': examType,
        'schoolId': institutionId,
        'institutionId': institutionId,
        'sectionId': sectionId,
      },
    ),
    GridCardModel(
      title: 'Admission\nGuideline',
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
