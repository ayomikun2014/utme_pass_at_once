import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final String fullAppName = 'PASS AT ONCE CBT';
  String displayedText = '';

  // Typewriter effect for app name
  Future<void> typeWriterEffect() async {
    for (int i = 0; i < fullAppName.length; i++) {
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;
      setState(() {
        displayedText = fullAppName.substring(0, i + 1);
      });
    }

    // Call completion callback after typing completes (giving a small grace period)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Safer null-aware call
    widget.onComplete?.call();
  }

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start typewriter effect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      typeWriterEffect();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash screens usually enforce brand colors rather than dynamic themes,
    // so leaving AppColors.primary and Colors.white here is correct.
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // 🫧 Bubbles (Optimized with GPU-accelerated Transform)
          _AnimatedBubble(controller: _controller, size: 40, left: 50, startBottom: -50),
          _AnimatedBubble(controller: _controller, size: 60, left: 150, startBottom: -50),
          _AnimatedBubble(controller: _controller, size: 30, left: 250, startBottom: -50),
          _AnimatedBubble(controller: _controller, size: 50, left: 100, startBottom: -50),

          // 🌟 Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with Glow + Animation (Optimized Shadow)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // 1. Scale the entire container rather than animating the blurRadius.
                    // This achieves the pulse effect without killing the GPU.
                    return Transform.scale(
                      scale: 0.9 + (_controller.value * 0.2),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20, // Static blur is cheap
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/app_logo.webp',
                          width: 140,
                          height: 140,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 25),
                Text(
                  displayedText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Extracted widget to keep the tree clean and handle translations natively
class _AnimatedBubble extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final double left;
  final double startBottom;

  const _AnimatedBubble({
    required this.controller,
    required this.size,
    required this.left,
    required this.startBottom,
  });

  @override
  Widget build(BuildContext context) {
    // Positioned stays static. This prevents Stack layout recalculations.
    return Positioned(
      bottom: startBottom,
      left: left,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          // Transform.translate only affects the paint phase (60fps guaranteed)
          return Transform.translate(
            offset: Offset(0, -(controller.value * 200)),
            child: Opacity(
              opacity: 0.2,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}