import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_settings_model.dart';

// STORE ITEM CLASS
class StoreItem {
  final String id;
  final String title;
  final String? subtitle;
  final String image;
  final Color baseColor;
  final double price;
  final String description;
  final bool isOutOfStock;

  StoreItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.image,
    required this.baseColor,
    required this.price,
    required this.description,
    required this.isOutOfStock,
  });
}

// --- STORE DATA ---
// Which of these can actually be bought is decided in the admin panel, under
// Settings -> Pricing & Monetization, and read from there every time the store
// is built. Adding a new exam no longer needs a new release.
List<StoreItem> getStoreCards(AppSettingsModel settings) {
  return [
    // 1. POST-UTME CBT SIMULATOR (NEW — available)
    StoreItem(
      id: 'post_utme',
      title: 'Post-UTME CBT Simulator',
      subtitle: 'University-specific screening practice',
      image: 'assets/images/post_utme.webp',
      baseColor: AppColors.dynamicColors[4],
      isOutOfStock: !settings.postUtmeOnSale,
      price: settings.postUtmePrice.toDouble(),
      description:
          "Ace your Post-UTME screening with the PASS AT ONCE Post-UTME Simulator. Designed specifically for university admission seekers, this tool provides institution-specific past questions from top Nigerian universities.\n\n"
          "Whether you're writing for OAU, UNILAG, UI, UNILORIN, or UNIABUJA, this simulator gives you the exact question style and difficulty of your target school. Detailed solutions help you understand every answer.\n\n"
          "How the code works: A single activation code works exclusively for ONE device. Upon activation, it unlocks the complete Post-UTME past question database for offline practice without any hidden subscription fees.",
    ),

    // 2. WAEC CBT SIMULATOR (available)
    StoreItem(
      id: 'waec',
      title: 'WAEC CBT Simulator',
      subtitle: 'SSCE standard objective practice',
      image: 'assets/images/waec.webp',
      isOutOfStock: !settings.waecOnSale,
      baseColor: AppColors.dynamicColors[1],
      price: settings.waecPrice.toDouble(),
      description:
          "Secure your WAEC grades with the PASS AT ONCE WAEC Simulator. Designed specifically for SSCE candidates, this tool provides an extensive database of past objective questions to sharpen your accuracy and speed.\n\n"
          "Say goodbye to carrying bulky past question papers. This app helps you identify your weak points through performance tracking and provides detailed explanations for every answer, ensuring you fully understand the topics.\n\n"
          "How the code works: One activation code works exclusively for ONE device. Upon activation, it unlocks the complete WAEC past question database for offline practice without any hidden subscription fees.",
    ),

    // 3. JAMB UTME CBT SIMULATOR (coming soon)
    StoreItem(
      id: 'jamb',
      title: 'JAMB UTME CBT Simulator',
      subtitle: 'Full offline UTME simulator practice',
      image: 'assets/images/jamb.webp',
      isOutOfStock: !settings.jambOnSale,
      baseColor: AppColors.dynamicColors[0],
      price: settings.jambPrice.toDouble(),
      description:
          "Prepare efficiently for your JAMB UTME exams with the PASS AT ONCE Simulator. Get access to an extensive database of standard UTME past questions designed to mirror the exact CBT format.\n\n"
          "Eliminate the fear of the unknown by practicing in a realistic exam environment. The simulator tracks your speed, points out weaknesses, and provides in-depth explanations for every subject to ensure you cross your target cutoff mark.\n\n"
          "How the code works: Your purchased activation code is tied to ONE single device. It provides permanent, offline access to the entire JAMB UTME question bank without any recurring payments.",
    ),

    // 4. NECO CBT SIMULATOR (coming soon)
    StoreItem(
      id: 'neco',
      title: 'NECO CBT Simulator',
      subtitle: 'Standard SSCE offline revision practice',
      image: 'assets/images/neco.webp',
      isOutOfStock: !settings.necoOnSale,
      baseColor: AppColors.dynamicColors[2],
      price: settings.necoPrice.toDouble(),
      description:
          "Ace your Senior School Certificate Examinations with the PASS AT ONCE NECO Simulator. Gain access to thousands of verified NECO past questions across all subjects to boost your confidence.\n\n"
          "This simulator bridges the gap between studying and testing by allowing you to practice under time pressure. Review your answers with detailed explanations and track your readiness before the real exam begins.\n\n"
          "How the code works: Your purchased activation code is tied to ONE single device. It provides permanent, offline access to the entire NECO question bank without any recurring payments.",
    ),
  ];
}
