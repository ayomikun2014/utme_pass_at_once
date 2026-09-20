import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class SliverHomeCard extends StatefulWidget {
  const SliverHomeCard({super.key});

  @override
  State<SliverHomeCard> createState() => _SliverHomeCardState();
}

// Added SingleTickerProviderStateMixin for the AnimationController
class _SliverHomeCardState extends State<SliverHomeCard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _timer;
  late AnimationController _bubbleController;

  /// Drives the pulse on the unlock button.
  ///
  /// The button sat in teal on a teal card and readers were walking past it.
  /// A slow breath is enough to catch the eye without turning the card into a
  /// billboard; it only runs while there is something to unlock.
  late AnimationController _pulseController;

  final List<String> _slidingContent = [
    'assets/images/slidingcontent01.webp',
    'assets/images/slidingcontent02.webp',
    'assets/images/slidingcontent03.webp',
    'assets/images/slidingcontent04.webp',
  ];

  @override
  void initState() {
    super.initState();
    // Text sliding timer
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _slidingContent.length;
      });
    });

    // Bubble animation controller (8 seconds for a full floating loop)
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bubbleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Animated Bubbles
                AnimatedBuilder(
                  animation: _bubbleController,
                  builder: (context, child) {
                    final value = _bubbleController.value * 2 * math.pi;
                    return Stack(
                      children: [
                        // Bubble 1 (Top Right)
                        Positioned(
                          top: -30 + math.cos(value) * 15, // Drifts up and down
                          right:
                              -20 +
                              math.sin(value) * 15, // Drifts left and right
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        // Bubble 2 (Bottom Left)
                        Positioned(
                          bottom: -40 + math.sin(value) * 20,
                          left: -20 + math.cos(value) * 20,
                          child: Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        // Bubble 3 (Middle Right)
                        Positioned(
                          top:
                              50 +
                              math.cos(value + math.pi) *
                                  25, // math.pi offsets the movement so it moves opposite to Bubble 1
                          right: 120 + math.sin(value + math.pi) * 20,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        // Bubble 4 (Small, Top Left)
                        Positioned(
                          top:
                              20 +
                              math.sin(value * 2) *
                                  10, // * 2 makes it move twice as fast
                          left: 80 + math.cos(value * 2) * 10,
                          child: Container(
                            height: 20,
                            width: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Sliding Images taking full width & height (no margin, no padding)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final inAnimation = Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation);
                          final outAnimation = Tween<Offset>(
                            begin: const Offset(-1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation);

                          return SlideTransition(
                            position: child.key == ValueKey<int>(_currentIndex)
                                ? inAnimation
                                : outAnimation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: Image.asset(
                      _slidingContent[_currentIndex],
                      key: ValueKey<int>(_currentIndex),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),

                // Foreground Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0,),
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      final user = auth.currentUser;
                      final isPremium = user?.isPremium ?? false;
                      final hasUnlockedAny =
                          user?.examSelections.isNotEmpty ?? false;
                      final isActuallyPremium = isPremium || hasUnlockedAny;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                if (isActuallyPremium)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'PREMIUM',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // White on the teal card, so it reads as the one
                          // thing to press. Readers who already own an exam
                          // get the quiet translucent version instead.
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final t = isActuallyPremium
                                  ? 0.0
                                  : Curves.easeInOut.transform(
                                      _pulseController.value,
                                    );
                              return Transform.scale(
                                scale: 1 + t * 0.018,
                                child: Container(
                                  width: double.infinity,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isActuallyPremium
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: isActuallyPremium
                                        ? Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                          )
                                        : null,
                                    boxShadow: isActuallyPremium
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.white.withValues(
                                                alpha: 0.25 + t * 0.35,
                                              ),
                                              blurRadius: 12 + t * 14,
                                              spreadRadius: t * 2,
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/unlock');
                              },
                              icon: Icon(
                                isActuallyPremium
                                    ? Icons.add_rounded
                                    : Icons.lock_open_rounded,
                                color: isActuallyPremium
                                    ? Colors.white
                                    : AppColors.primary,
                                size: 20,
                              ),
                              label: Text(
                                isActuallyPremium
                                    ? 'Unlock More Exams'
                                    : 'Unlock Now',
                                style: TextStyle(
                                  color: isActuallyPremium
                                      ? Colors.white
                                      : AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),

                          // Sits under the button, clear of the artwork, so it
                          // explains the button without covering the card.
                            const SizedBox(height: 2),
                            Text(
                              'Enter your code to activate the full app and unlock exams.',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
