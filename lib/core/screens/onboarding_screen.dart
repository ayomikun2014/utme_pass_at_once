import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  void startAutoScroll() {
    _autoScrollTimer?.cancel();

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;

      if (_currentPage < onboardingPages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Cache theme for dynamic colors

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Replaced hardcoded splashBgLight
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            buildDotIndicators(),
            Expanded(child: onboardingContent(theme)),
            buildButtons(context, theme),
          ],
        ),
      ),
    );
  }

  Widget buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(onboardingPages.length, (index) {
        final isActive = _currentPage == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 30 : 9,
          height: 9,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  Widget onboardingContent(ThemeData theme) {
    return PageView.builder(
      controller: _pageController,
      itemCount: onboardingPages.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        startAutoScroll();
      },
      itemBuilder: (context, index) {
        final page = onboardingPages[index];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const Spacer(),

              Container(
                height: 450,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
                // Ensure these images are in your assets folder and declared in pubspec.yaml
                child: Image.asset(page.imagePath, fit: BoxFit.contain),
              ),

              const SizedBox(height: 24),

              Text(
                page.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                page.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant, // Adapts to Dark/Light mode natively
                ),
              ),

              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget buildButtons(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Row(
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
          const SizedBox(width: 14),
          Expanded(
            child: CustomBtn(
              label: 'Create Account',
              backgroundColor: Colors.transparent,
              borderColor: AppColors.primary,
              textColor: AppColors.primary,
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/signup');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// Updated Onboarding Pages with highly persuasive copy for the books
const List<OnboardingPage> onboardingPages = [
  OnboardingPage(
    title: 'Practice Smarter Every Day',
    description:
    'Practice real exam questions in a smart and interactive way. Improve your speed, accuracy, and confidence with every session.',
    imagePath: 'assets/images/onboarding2.webp',
  ),
  OnboardingPage(
    title: 'Track Progress and Succeed',
    description:
    'See your improvement clearly, review your results, and build the confidence you need to perform better in your exams.',
    imagePath: 'assets/images/onboarding3.webp',
  ),
  OnboardingPage(
    title: 'All Exams in One App',
    description:
    'Prepare for JAMB, Post UTME, WAEC, and NECO in one place. Access organized questions and tools without switching apps.',
    imagePath: 'assets/images/onboarding1.webp',
  ),
  // NEW PAGE: UTME 4-in-1 Book
  OnboardingPage(
    title: 'Crush JAMB with Achievers Series',
    description:
    'Get the ultimate edge! The 4-in-1 UTME Past Questions book breaks down complex topics with easy notes and innovative questions to guarantee your high score.',
    imagePath: 'assets/images/onboarding4.webp',
  ),
  // NEW PAGE: SSCE 14-in-1 Book
  OnboardingPage(
    title: '14 Subjects. 1 Ultimate Guide.',
    description:
    'Ace WAEC, NECO, and Post-UTME effortlessly. Master 14 subjects with over a decade of past questions and step-by-step detailed solutions built for champions.',
    imagePath: 'assets/images/onboarding5.webp',
  ),
];