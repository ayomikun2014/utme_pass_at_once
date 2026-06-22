// lib/core/utils/custom_fallback_image.dart
import 'package:flutter/material.dart';

class CustomFallbackImage extends StatelessWidget {
  final double width;
  final double height;
  final double logoScale; // How big the logo should be relative to the container

  const CustomFallbackImage({
    super.key,
    this.width = 70,
    this.height = 70,
    this.logoScale = 0.4, // Logo takes up 40% of the container by default
  });

  @override
  Widget build(BuildContext context) {
    // Automatically detect theme inside the widget so you don't have to pass it!
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate logo size based on the smallest dimension
    final double minDimension = width < height ? width : height;
    final double actualLogoSize = minDimension * logoScale;

    return Container(
      width: width,
      height: height,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      child: Center(
        child: Image.asset(
          'assets/images/app_logo.webp',
          width: actualLogoSize,
          height: actualLogoSize,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}