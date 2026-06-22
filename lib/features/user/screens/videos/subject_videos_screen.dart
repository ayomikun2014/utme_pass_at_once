import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:utme_pass_at_once/core/utils/custom_grid_card.dart';
import 'package:utme_pass_at_once/features/user/models/video_model.dart';
import 'package:utme_pass_at_once/features/user/providers/video_provider.dart';
import '../../utils/custom_fallback_image.dart';
import 'video_player_screen.dart';

class SubjectVideosScreen extends StatefulWidget {
  final String subject;

  const SubjectVideosScreen({super.key, required this.subject});

  @override
  State<SubjectVideosScreen> createState() => _SubjectVideosScreenState();
}

class _SubjectVideosScreenState extends State<SubjectVideosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final videoProvider = context.watch<VideoProvider>();

    final allVideos = videoProvider.getVideosForSubject(widget.subject, search: _searchQuery);
    final favoriteVideos = videoProvider.getFavoritesForSubject(widget.subject, search: _searchQuery);

    final visual = _getSubjectVisualDetails(widget.subject);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 180.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.subject.toUpperCase(),
                      style: const TextStyle(
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
                          'assets/images/video_topic_banner.webp',
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
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Tab Header Control
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: [visual.gradientStart, visual.gradientEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: isDark ? Colors.white60 : Colors.black87,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: "All Lessons"),
                              Tab(text: "My Favorites"),
                            ],
                          ),
                        ),
                      ),

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: "Search topics...",
                              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                              prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white60 : Colors.black45),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildVideoList(allVideos, videoProvider, visual, isDark, "No lessons found"),
                _buildVideoList(favoriteVideos, videoProvider, visual, isDark, "No favorites added yet"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(
    List<VideoModel> videos,
    VideoProvider provider,
    _SubjectVisual visual,
    bool isDark,
    String emptyMessage,
  ) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          final isFav = provider.isFavorited(video.id);

          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 600),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomGridCard(
                      title: video.title,
                      route: '', // Handled by onTap
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(video: video),
                          ),
                        );
                      },
                      baseColor: visual.gradientStart,
                      icon: Icons.play_circle_outline_rounded,
                      requiresNetwork: false,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? Colors.redAccent : (isDark ? Colors.white54 : Colors.black45),
                            size: 16,
                          ),
                          onPressed: () {
                            provider.toggleFavorite(video.id);
                          },
                        ),
                      ),
                    ),
                    if (video.duration.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Visuals helper identical to parent screen ---

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
