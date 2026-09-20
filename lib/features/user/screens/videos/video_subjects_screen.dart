import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:utme_pass_at_once/core/utils/custom_grid_card.dart';
import 'package:utme_pass_at_once/features/user/providers/video_provider.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import '../../utils/custom_fallback_image.dart';
import 'subject_videos_screen.dart';
import '../../../../core/services/tutorial_service.dart';

class VideoSubjectsScreen extends StatefulWidget {
  const VideoSubjectsScreen({super.key});

  @override
  State<VideoSubjectsScreen> createState() => _VideoSubjectsScreenState();
}

class _VideoSubjectsScreenState extends State<VideoSubjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isPremium = user?.isPremium ?? false;

    final videoProvider = context.watch<VideoProvider>();
    final subjects = videoProvider.getSubjectsForSelectedTrack(search: _searchQuery);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          AnimationLimiter(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 220.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Video Tutorials',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.0,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    centerTitle: true,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/video_banner.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const CustomFallbackImage(
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (!isPremium)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildPremiumUpsellCard(theme, isDark),
                  )
                else ...[
                  // Search & Filter section
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(theme, isDark),
                        _buildTrackSelectionChips(theme, isDark, videoProvider),
                      ],
                    ),
                  ),
                  
                  // Subjects Grid
                  if (videoProvider.isLoading && subjects.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (subjects.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80.0),
                        child: _buildEmptyState(isDark),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final subject = subjects[index];
                            final visual = _getSubjectVisualDetails(subject);
                            
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 600),
                              columnCount: 2,
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: CustomGridCard(
                                    title: subject.toUpperCase(),
                                    route: '', // Handled by onTap
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SubjectVideosScreen(subject: subject),
                                        ),
                                      );
                                    },
                                    baseColor: visual.gradientStart,
                                    icon: visual.icon,
                                    requiresNetwork: false,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: subjects.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Component Builders ---

  Widget _buildTrackSelectionChips(ThemeData theme, bool isDark, VideoProvider provider) {
    return TutorialService.instance.buildShowcase(
      key: TutorialService.instance.tutorialTrackKey,
      icon: Icons.category_rounded,
      accent: const Color(0xFF7C3AED),
      title: 'Your track',
      description: 'Show only the subjects you sit: All, Science or Art. The list below changes with your choice.',
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select any subject to watch expert-led lectures and tutorials.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: ['all', 'science', 'art'].map((track) {
                final isSelected = provider.selectedTrack == track;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      track.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        provider.setTrack(track);
                      }
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? AppColors.dividerDark : Colors.grey.shade300),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return TutorialService.instance.buildShowcase(
      key: TutorialService.instance.tutorialSearchKey,
      icon: Icons.search_rounded,
      accent: const Color(0xFF0EA5E9),
      title: 'Find a subject fast',
      description: 'Type a subject to jump straight to its video lessons instead of scrolling the whole list.',
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: "Search subjects...",
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
              prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white60 : Colors.black45),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            "No tutorial subjects found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try checking other tracks or query settings.",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  _SubjectVisual _getSubjectVisualDetails(String subject) {
    final key = subject.trim().toLowerCase();

    if (key.contains('physics')) {
      return _SubjectVisual(
        icon: Icons.science_rounded,
        gradientStart: const Color(0xFF3F51B5),
        gradientEnd: const Color(0xFF303F9F),
      );
    }
    if (key.contains('chemistry')) {
      return _SubjectVisual(
        icon: Icons.biotech_rounded,
        gradientStart: const Color(0xFF009688),
        gradientEnd: const Color(0xFF00796B),
      );
    }
    if (key.contains('biology')) {
      return _SubjectVisual(
        icon: Icons.psychology_rounded,
        gradientStart: const Color(0xFF4CAF50),
        gradientEnd: const Color(0xFF388E3C),
      );
    }
    if (key.contains('math') || key.contains('arithmetic')) {
      return _SubjectVisual(
        icon: Icons.calculate_rounded,
        gradientStart: const Color(0xFFFF5722),
        gradientEnd: const Color(0xFFD84315),
      );
    }
    if (key.contains('english') || key.contains('literature') || key.contains('lang')) {
      return _SubjectVisual(
        icon: Icons.menu_book_rounded,
        gradientStart: const Color(0xFF9C27B0),
        gradientEnd: const Color(0xFF7B1FA2),
      );
    }
    if (key.contains('government') || key.contains('history') || key.contains('civic')) {
      return _SubjectVisual(
        icon: Icons.gavel_rounded,
        gradientStart: const Color(0xFFE91E63),
        gradientEnd: const Color(0xFFC2185B),
      );
    }
    if (key.contains('geo') || key.contains('agric')) {
      return _SubjectVisual(
        icon: Icons.public_rounded,
        gradientStart: const Color(0xFF8BC34A),
        gradientEnd: const Color(0xFF689F38),
      );
    }
    if (key.contains('account') || key.contains('commerce') || key.contains('econ')) {
      return _SubjectVisual(
        icon: Icons.monetization_on_rounded,
        gradientStart: const Color(0xFF00BCD4),
        gradientEnd: const Color(0xFF0097A7),
      );
    }

    return _SubjectVisual(
      icon: Icons.import_contacts_rounded,
      gradientStart: const Color(0xFF673AB7),
      gradientEnd: const Color(0xFF512DA8),
    );
  }

  Widget _buildPremiumUpsellCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 30.0, 24.0, 40.0),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8F00).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFF8F00),
                  size: 40,
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 1000.ms,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                "Unlock Video Tutorials! 🎬",
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 14),

              // Description
              Text(
                "Access expert-led video lessons specifically designed for JAMB, WAEC, NECO, and Post-UTME.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),

              const SizedBox(height: 20),

              // Single TextButton CTA
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/store');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: Text(
                  "Buy Activation Code",
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFFF8F00),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _SubjectVisual {
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  _SubjectVisual({
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
  });
}
