import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_settings_model.dart';

// CLASS FOR FEATURES
class ExamFeature {
  final String title;
  final String description;

  ExamFeature({required this.title, required this.description});
}

// STORE ITEM CLASS
class StoreItem {
  final String id;
  final String title;
  final String image;
  final Color baseColor;
  final double price;
  final String description;
  final bool isOutOfStock;
  final List<ExamFeature> features;

  StoreItem({
    required this.id,
    required this.title,
    required this.image,
    required this.baseColor,
    required this.price,
    required this.description,
    required this.features,
    required this.isOutOfStock,
  });
}

// --- STORE DATA ---
// Post-UTME & WAEC are available. JAMB UTME & NECO are coming soon.
List<StoreItem> getStoreCards(AppSettingsModel settings) {
  return [
    // 1. POST-UTME CBT SIMULATOR (NEW — available)
    StoreItem(
      id: 'post_utme',
      title: 'Post-UTME CBT Simulator',
      image: 'assets/images/post_utme.webp',
      baseColor: AppColors.dynamicColors[4],
      isOutOfStock: false,
      price: settings.postUtmePrice.toDouble(),
      description:
          "Ace your Post-UTME screening with the PASS AT ONCE Post-UTME Simulator. Designed specifically for university admission seekers, this tool provides institution-specific past questions from top Nigerian universities.\n\n"
          "Whether you're writing for OAU, UNILAG, UI, UNILORIN, or UNIABUJA, this simulator gives you the exact question style and difficulty of your target school. Detailed solutions help you understand every answer.\n\n"
          "How the code works: A single activation code works exclusively for ONE device. Upon activation, it unlocks the complete Post-UTME past question database for offline practice without any hidden subscription fees.",
      features: [
        ExamFeature(
          title: '1. University-Specific Questions',
          description:
              'Practice with real past questions from your specific university, organized by subject and year.',
        ),
        ExamFeature(
          title: '2. Real CBT Experience',
          description:
              'Simulates the actual Post-UTME CBT environment with timing, navigation, and calculator tools.',
        ),
        ExamFeature(
          title: '3. Works 100% Offline',
          description:
              'Study anywhere, anytime. No data or internet connection is required after your one-time activation.',
        ),
        ExamFeature(
          title: '4. Detailed Explanations',
          description:
              'Learn from comprehensive step-by-step solutions for every question to master each topic.',
        ),
      ],
    ),

    // 2. WAEC CBT SIMULATOR (available)
    StoreItem(
      id: 'waec',
      title: 'WAEC CBT Simulator',
      image: 'assets/images/waec.webp',
      isOutOfStock: true,
      baseColor: AppColors.dynamicColors[1],
      price: settings.waecPrice.toDouble(),
      description:
          "Secure your WAEC grades with the PASS AT ONCE WAEC Simulator. Designed specifically for SSCE candidates, this tool provides an extensive database of past objective questions to sharpen your accuracy and speed.\n\n"
          "Say goodbye to carrying bulky past question papers. This app helps you identify your weak points through performance tracking and provides detailed explanations for every answer, ensuring you fully understand the topics.\n\n"
          "How the code works: One activation code works exclusively for ONE device. Upon activation, it unlocks the complete WAEC past question database for offline practice without any hidden subscription fees.",
      features: [
        ExamFeature(
          title: '1. SSCE Standard Practice',
          description:
              'Practice with thousands of official WAEC past questions updated according to the current syllabus.',
        ),
        ExamFeature(
          title: '2. Detailed Solutions',
          description:
              'Learn from your mistakes with comprehensive, step-by-step explanations for every question.',
        ),
        ExamFeature(
          title: '3. Topic-by-Topic Study',
          description:
              'Focus your studies by filtering questions based on specific topics you want to master.',
        ),
        ExamFeature(
          title: '4. Works 100% Offline',
          description:
              'Study anywhere, anytime. No data or internet connection is required after your one-time activation.',
        ),
      ],
    ),

    // 3. JAMB UTME CBT SIMULATOR (coming soon)
    StoreItem(
      id: 'jamb',
      title: 'JAMB UTME CBT Simulator',
      image: 'assets/images/jamb.webp',
      isOutOfStock: true,
      baseColor: AppColors.dynamicColors[0],
      price: settings.jambPrice.toDouble(),
      description:
          "Prepare efficiently for your JAMB UTME exams with the PASS AT ONCE Simulator. Get access to an extensive database of standard UTME past questions designed to mirror the exact CBT format.\n\n"
          "Eliminate the fear of the unknown by practicing in a realistic exam environment. The simulator tracks your speed, points out weaknesses, and provides in-depth explanations for every subject to ensure you cross your target cutoff mark.\n\n"
          "How the code works: Your purchased activation code is tied to ONE single device. It provides permanent, offline access to the entire JAMB UTME question bank without any recurring payments.",
      features: [
        ExamFeature(
          title: '1. Authentic CBT Interface',
          description:
              'Experience the exact look, feel, and functionality of the official JAMB UTME exam software.',
        ),
        ExamFeature(
          title: '2. Subject Combination Practice',
          description:
              'Practice your specific 4 subjects simultaneously just like the real exam day.',
        ),
        ExamFeature(
          title: '3. In-Depth Explanations',
          description:
              'Understand the "Why" behind every answer with our comprehensive solution guides.',
        ),
        ExamFeature(
          title: '4. Works 100% Offline',
          description:
              'Study completely offline after activation, saving your mobile data for other things.',
        ),
      ],
    ),

    // 4. NECO CBT SIMULATOR (coming soon)
    StoreItem(
      id: 'neco',
      title: 'NECO CBT Simulator',
      image: 'assets/images/neco.webp',
      isOutOfStock: true,
      baseColor: AppColors.dynamicColors[2],
      price: settings.necoPrice.toDouble(),
      description:
          "Ace your Senior School Certificate Examinations with the PASS AT ONCE NECO Simulator. Gain access to thousands of verified NECO past questions across all subjects to boost your confidence.\n\n"
          "This simulator bridges the gap between studying and testing by allowing you to practice under time pressure. Review your answers with detailed explanations and track your readiness before the real exam begins.\n\n"
          "How the code works: Your purchased activation code is tied to ONE single device. It provides permanent, offline access to the entire NECO question bank without any recurring payments.",
      features: [
        ExamFeature(
          title: '1. Standardized NECO Questions',
          description:
              'Access years of compiled NECO past questions to understand their specific question patterns.',
        ),
        ExamFeature(
          title: '2. Performance Analytics',
          description:
              'Track your progress over time and see detailed breakdowns of your strengths and weaknesses.',
        ),
        ExamFeature(
          title: '3. Detailed Solutions',
          description:
              'Learn from comprehensive step-by-step solutions for every question to master each topic.',
        ),
        ExamFeature(
          title: '4. Works 100% Offline',
          description:
              'Study anywhere, anytime. No data or internet connection is required after your one-time activation.',
        ),
      ],
    ),
  ];
}
