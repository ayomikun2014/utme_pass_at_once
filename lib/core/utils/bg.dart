import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // We use a very faint version of your primary color for the lines.
    // It's slightly more visible in dark mode to create a sleek "glowing wire" effect.
    final Color lineBaseColor = isDark
        ? AppColors.primaryDark
        : AppColors.primary;
    final Color lineColor = lineBaseColor.withValues(
      alpha: isDark ? 0.08 : 0.06,
    );

    // A secondary color for the bottom left to balance the screen
    final Color accentLineColor = AppColors.accent.withValues(
      alpha: isDark ? 0.05 : 0.06,
    );

    return Stack(
      children: [
        // --- TOP RIGHT RIPPLES (Primary Color) ---
        // Outer Ring
        Positioned(
          top: -150,
          right: -100,
          child: _buildRing(size: 450, color: lineColor, strokeWidth: 1.5),
        ),
        // Middle Ring
        Positioned(
          top: -70,
          right: -20,
          child: _buildRing(size: 280, color: lineColor, strokeWidth: 1.5),
        ),
        // Inner Ring
        Positioned(
          top: 10,
          right: 60,
          child: _buildRing(
            size: 120,
            color: lineColor,
            strokeWidth: 2.0,
          ), // Slightly thicker center
        ),

        // --- BOTTOM LEFT RIPPLE (Accent Color) ---
        Positioned(
          bottom: -80,
          left: -80,
          child: _buildRing(
            size: 250,
            color: accentLineColor,
            strokeWidth: 1.5,
          ),
        ),
        Positioned(
          bottom: -20,
          left: -20,
          child: _buildRing(
            size: 100,
            color: accentLineColor,
            strokeWidth: 1.5,
          ),
        ),
      ],
    );
  }

  // A small helper widget to keep our code clean and reusable
  Widget _buildRing({
    required double size,
    required Color color,
    required double strokeWidth,
  }) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: strokeWidth),
      ),
    );
  }
}
