import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_state.dart';
import '../../models/news_model.dart';
import '../../providers/news_provider.dart';
import '../../utils/custom_fallback_image.dart';
import 'news_reader_screen.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/utils/custom_toast.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isCollapsed = _scrollController.offset > (300.0 - kToolbarHeight);
      if (isCollapsed != _isCollapsed) {
        setState(() {
          _isCollapsed = isCollapsed;
        });
      }
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final newsProvider = context.read<NewsProvider>();
      if (!newsProvider.isLoadingMore && newsProvider.hasMore) {
        newsProvider.loadMoreNews();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final newsProvider = context.watch<NewsProvider>();

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          final hasInternet = await NetworkService.instance.hasInternet();
          if (!hasInternet) {
            if (context.mounted) {
              CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
            }
            return;
          }
          if (!context.mounted) return;
          await context.read<NewsProvider>().refreshNews();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          // --- 1. THE FLEXIBLE APP BAR ---
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: (newsProvider.featuredNews == null || _isCollapsed)
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.white, // Clean white contrast over the dark featured news background
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Education News',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: (newsProvider.featuredNews == null || _isCollapsed)
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.white, // Clean white contrast over the dark featured news background
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: newsProvider.featuredNews != null
                  ? _buildFeaturedNews(
                newsProvider.featuredNews!,
                theme,
                isDark,
                context,
              )
                  : const SizedBox(),
            ),
          ),

          // --- 2. THE NEWS LIST LOGIC ---
          if (newsProvider.isLoading && newsProvider.newsList.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CustomLoader()),
              ),
            )
          else if (newsProvider.newsList.isEmpty)
            buildErrorState(context, newsProvider)
          else
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final newsItem = newsProvider.remainingNews[index];
                  return _buildNewsCard(newsItem, theme, isDark, context);
                }, childCount: newsProvider.remainingNews.length),
              ),
            ),

          // Bottom loading spinner
          if (newsProvider.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(child: CustomLoader()),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
     ),
    );
  }

  Widget _buildFeaturedNews(
      NewsModel news,
      ThemeData theme,
      bool isDark,
      BuildContext context,
      ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // --- FIXED: Featured Image Fallback Logic ---
        news.imageUrl.isEmpty
            ? const CustomFallbackImage(width: double.infinity, height: double.infinity)
            : Image.network(
          news.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const CustomFallbackImage(width: double.infinity, height: double.infinity),
        ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.9),
                Colors.black.withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                news.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewsReaderScreen(news: news),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Read More'),
                  ),
                  Text(
                    news.pubDate,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(
      NewsModel news,
      ThemeData theme,
      bool isDark,
      BuildContext context,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsReaderScreen(news: news)),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.source,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    news.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // A taste of the story, so the list is readable on its own.
                  if (news.body.trim().isNotEmpty &&
                      news.body.trim() != news.title.trim()) ...[
                    const SizedBox(height: 6),
                    Text(
                      news.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    news.pubDate,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // --- FIXED: Thumbnail Fallback Logic ---
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: news.imageUrl.isEmpty
                  ? const CustomFallbackImage(width: double.infinity, height: double.infinity)
                  : Image.network(
                news.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const CustomFallbackImage(width: double.infinity, height: double.infinity)
              ),
            ),
          ],
        ),
      ),
    );
  }
}