import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding.webp',
              fit: BoxFit.cover,
            ),
          ),

          // Premium Dark Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Content Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Spacer(),

                  // Title Text
                  Text(
                    'PASS YOUR EXAMS\nWITH CONFIDENCE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                      letterSpacing: 0.5,
                    ),
                  )
                      .animate()
                      .fade(delay: 200.ms, duration: 800.ms)
                      .slideY(begin: 0.2, end: 0.0, curve: Curves.easeOutQuad),

                  const SizedBox(height: 16),

                  // Subtitle Text
                  Text(
                    'Practice JAMB, WAEC, NECO and Post-UTME questions anytime, anywhere.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  )
                      .animate()
                      .fade(delay: 400.ms, duration: 800.ms)
                      .slideY(begin: 0.2, end: 0.0, curve: Curves.easeOutQuad),

                  const SizedBox(height: 40),

                  // Navigation Buttons (Login / Create Account)
                  Row(
                    children: [
                      Expanded(
                        child: CustomBtn(
                          label: 'Login',
                          backgroundColor: AppColors.primary,
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomBtn(
                          label: 'Create Account',
                          backgroundColor: Colors.transparent,
                          borderColor: Colors.white,
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/signup');
                          },
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fade(delay: 600.ms, duration: 800.ms)
                      .slideY(begin: 0.2, end: 0.0, curve: Curves.easeOutQuad),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}