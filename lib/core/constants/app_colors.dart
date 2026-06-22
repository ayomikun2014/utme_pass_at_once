import 'package:flutter/material.dart';

class AppColors {
  // Private constructor
  AppColors._();

  // --- Brand Colors ---
  static const Color primary = Color(0xFF0D9488); // Primary teal color
  static const Color primaryDark = Color(0xFF14B8A6); // Lighter teal for dark mode
  static const Color accent = Color(0xFFF59E0B); // Accent amber

  // --- Theme Colors (Light) ---
  static const Color backgroundLight = Color(0xFFF8FAFB);
  static const Color surfaceLight = Colors.white;
  static const Color dividerLight = Color(0xFFE5E7EB);

  // --- Theme Colors (Dark) ---
  static const Color backgroundDark = Color(0xFF1A1E1E);
  static const Color surfaceDark = Color(0xFF242A2A);
  static const Color dividerDark = Color(0xFF374151);

  // --- Semantic & Status Colors ---
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFFB300);

  // --- Dynamic UI Colors (Used for Categories, Exams, Institutions) ---
  static const List<Color> dynamicColors = [
    Color(0xFF0D9488), // Teal
    Color(0xFF2563EB), // Cobalt Blue
    Color(0xFFF43F5E), // Rose Coral
    Color(0xFFF59E0B), // Soft Gold
    Color(0xFF7C3AED), // Royal Violet
    Color(0xFFEC4899), // Sophisticated Pink
  ];
}

// --- Gradients ---
class AppGradients {
  AppGradients._();

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D9488), // Teal
      Color(0xFF14B8A6), // Lighter teal
    ],
  );
}