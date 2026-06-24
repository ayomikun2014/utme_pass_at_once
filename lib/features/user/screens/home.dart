import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/features/user/screens/more/news_reader_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/bg.dart';
import '../../../core/utils/custom_app_bar.dart';
import '../../../core/utils/custom_grid_card.dart';
import '../../../core/utils/error_state.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/models/user_model.dart';
import '../models/ui_grid_card_details.dart';
import '../providers/news_provider.dart';
import '../providers/simulator_provider.dart';
import '../utils/activation_bottom_sheet.dart';
import '../utils/custom_fallback_image.dart';
import '../utils/sliver_home_card.dart';
import '../utils/main_shell.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import '../../../core/services/tutorial_service.dart';
import '../../../core/services/network_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  /// Pull-to-refresh: refreshes user data from Firestore + reloads news.
  Future<void> _onRefresh() async {
    final isOnline = NetworkService.instance.isOnline;
    if (!isOnline) {
      if (mounted) {
        CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
      }
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final newsProvider = context.read<NewsProvider>();

    await Future.wait([authProvider.refreshUser(), newsProvider.loadNews()]);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch the News Provider & Auth Provider
    final newsProvider = context.watch<NewsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final String firstName = (user?.displayName ?? 'Guest').trim().split(' ').first;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: AnimationLimiter(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  CustomAppBar(
                    title: 'Hello, $firstName',
                    subtitle: 'Welcome back! Ready to practice?',
                    icon: Icons.notifications_none_rounded,
                    color: AppColors.dynamicColors[2].withValues(alpha: 0.90),
                    route: user == null ? '/login' : '/notification_history',
                    centerTitle: false,
                    hasIcon: true,
                    hideTitleOnCollapse: true,
                    onTitlePressed: () {
                      if (user == null) {
                        Navigator.pushNamed(context, '/login');
                      } else {
                        Navigator.pushNamed(context, '/my_account');
                      }
                    },
                    actions: [
                      TutorialService.instance.buildShowcase(
                        key: TutorialService.instance.settingsKey,
                        title: 'Preferences & Help ⚙️',
                        description: 'Access settings to change your theme, configure notifications, contact support, or replay this tour.',
                        context: context,
                        isCircleBorder: true,
                        child: IconButton(
                          onPressed: () => Navigator.pushNamed(context, user == null ? '/login' : '/settings'),
                          icon: const Icon(Icons.settings_rounded, color: Colors.grey, size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SliverHomeCard(),
                  const _ExamCategorySlider(),

                  buildSubHeading('Quick Links', context, user: user),
                  buildQuickLinkCard(user),

                  buildSubHeading(
                    'Latest News',
                    context,
                    isViewAll: true,
                    route: '/news',
                    user: user,
                    btnText: 'Read More',
                  ),

                  // 2. DYNAMIC NEWS SECTION
                  if (newsProvider.isLoading && newsProvider.newsList.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CustomLoader()),
                      ),
                    )
                  else if (newsProvider.newsList.isEmpty)
                  // Show the beautiful Error/No Signal state
                    buildErrorState(context, newsProvider)
                  else
                  // Show the News List
                    _buildNewsList(context, newsProvider),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---HOME NEWS LIST ---
  Widget _buildNewsList(BuildContext context, NewsProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final news = provider.newsList[index];
            Widget card = InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NewsReaderScreen(news: news),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  news.source,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  news.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  news.pubDate,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Image Fallback Logic
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: news.imageUrl.isEmpty
                                ? const CustomFallbackImage(width: 70, height: 70)
                                : Image.network(
                              news.imageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const CustomFallbackImage(width: 70, height: 70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

            if (index == 0) {
              card = TutorialService.instance.buildShowcase(
                key: TutorialService.instance.newsKey,
                title: 'Latest Updates 📰',
                description: 'Stay informed with real-time news updates, exam schedules, and academic tips directly on your feed.',
                context: context,
                child: card,
              );
            }

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 600),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: card,
                ),
              ),
            );
          },
          childCount: provider.newsList.length > 5 ? 5 : provider.newsList.length,
        ),
      ),
    );
  }

  // --- SUB HEADING ---
  Widget buildSubHeading(
      String title,
      BuildContext context, {
        bool? isViewAll = false,
        String? route,
        UserModel? user,
        String? btnText,
      }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (isViewAll!)
              TextButton(
                onPressed: () {
                  if (user == null) {
                    Navigator.pushNamed(context, '/login');
                  } else if (route != null) {
                    Navigator.pushNamed(context, route);
                  }
                },
                child: Text(btnText ?? 'View All'),
              ),
          ],
        ),
      ),
    );
  }

  // --- QUICK LINK CARD ---
  Widget buildQuickLinkCard(UserModel? user) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final feature = homeFeatureList[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 600),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: () {
                  Widget card = CustomGridCard(
                    onTap: () {
                      if (user == null) {
                        Navigator.pushNamed(context, '/login');
                        return;
                      }
                      if (feature.route == '/ai_chat') {
                        MainShell.openAIChat(context);
                      } else {
                        Navigator.pushNamed(context, feature.route);
                      }
                    },
                    title: feature.title,
                    route: feature.route,
                    baseColor: feature.baseColor,
                    icon: feature.icon,
                    imagePath: feature.imagePath,
                    requiresNetwork: feature.requiresNetwork,
                  );

                  if (index == 0) {
                    card = TutorialService.instance.buildShowcase(
                       key: TutorialService.instance.quickLinksKey,
                       title: 'Quick Navigation ⚡',
                       description: 'Quickly access the Exam Store, check your Purchase History, chat with Cognita AI, or read announcements.',
                       context: context,
                       child: card,
                     );
                   }
                   return card;
                }(),
              ),
            ),
          );
        }, childCount: homeFeatureList.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
      ),
    );
  }
}

// ============================================================================
// Exam Category Slider Widget (Infinite Continuous Scroll)
// ============================================================================

class _ExamCategorySlider extends StatefulWidget {
  const _ExamCategorySlider();

  @override
  State<_ExamCategorySlider> createState() => _ExamCategorySliderState();
}

class _ExamCategorySliderState extends State<_ExamCategorySlider> {
  late ScrollController _scrollController;
  Timer? _sliderTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSlide();
    });
  }

  void _startAutoSlide() {
    _sliderTimer?.cancel();
    _sliderTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        // Because the list is now infinite, we just keep pushing forward!
        // No more snapping back to zero.
        _scrollController.jumpTo(_scrollController.offset + 1.0);
      }
    });
  }

  void _stopAutoSlide() {
    _sliderTimer?.cancel();
  }


  Future<void> _handleExamTap(
      BuildContext context,
      Map<String, dynamic> cat,
      ) async {
    final String title = cat['title'] as String;
    final bool isAvailable = cat['isAvailable'] as bool? ?? false;

    if (!isAvailable) {
      CustomToast.show(context, '$title Preparation coming soon!');
      return;
    }

    final String route = cat['route'] as String;
    final String examType = cat['examType'] as String? ?? '';

    if (examType.isEmpty) {
      Navigator.pushNamed(context, route);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final simProvider = context.read<SimulatorProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    final isPremiumOnThisDevice = authProvider.hasPremiumAccessFor(examType);
    final isPremiumAnyDevice = authProvider.hasPremiumAnyDevice(examType);

    if (isPremiumAnyDevice && !isPremiumOnThisDevice) {
      if (context.mounted) _showDeviceMismatchDialog(context, examType, route);
      return;
    }

    if (isPremiumOnThisDevice) {
      final activatedCenters = user.getExamCenters(examType);

      bool hasMissingPackage = false;
      String missingInstitutionId = '';
      String? missingSectionId;

      for (final institutionKey in activatedCenters) {
        // Use getSectionForInstitution for consistent sectionId with update.dart
        final section = user.getSectionForInstitution(examType, institutionKey);
        final sectionId = section?['id'];

        final baseInstitutionId = examType == 'post_utme' && institutionKey.contains('_')
            ? institutionKey.split('_').first
            : institutionKey;

        final downloaded = await simProvider.isActivatedPackageDownloaded(
          examType: examType,
          institutionId: baseInstitutionId,
          sectionId: sectionId,
        );

        if (!downloaded) {
          hasMissingPackage = true;
          missingInstitutionId = baseInstitutionId;
          missingSectionId = sectionId;
          break;
        }
      }

      if (hasMissingPackage && context.mounted) {
        _showMissingDataDialog(
          context,
          examType,
          missingInstitutionId,
          route, // Need to pass route here!
          sectionId: missingSectionId,
        );
        return;
      }
    }

    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      route,
      arguments: {'examType': examType},
    );
  }

  void _autoDownloadAndNavigate(
      BuildContext context,
      String examType,
      String institutionId,
      String route, {
        String? sectionId,
      }) {
    final provider = context.read<SimulatorProvider>();

    final downloadFuture = provider.downloadActivationData(
      examType: examType,
      institutionId: institutionId,
      sectionId: sectionId,
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ActivationBottomSheet(
        task: () => downloadFuture,
        onComplete: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushNamed(
                context,
                route,
                arguments: {'examType': examType},
              );
            }
          });
        },
      ),
    );
  }

  void _showMissingDataDialog(
      BuildContext context,
      String examType,
      String institutionId,
      String route, {
        String? sectionId,
      }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cloud_download_outlined, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Missing Offline Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your premium exam data is incomplete or missing from this device. '
              'This usually happens if you cleared your app cache, or if a previous download was interrupted.\n\n'
              'Would you like to restore your offline data now?',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close the dialog
              // Trigger the actual download
              _autoDownloadAndNavigate(
                context,
                examType,
                institutionId,
                route,
                sectionId: sectionId,
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  void _showDeviceMismatchDialog(BuildContext context, String examType, String route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.phonelink_off_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Different Device',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your premium access for this exam was activated on a different device. '
              'To access premium content on this device, you\'ll need a new activation code.\n\n'
              'You can also try the free version with limited questions.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // Free Trial button
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(
                context,
                route,
                arguments: {'examType': examType},
              ); // Free trial uses the same route
            },
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Free Trial'),
          ),
          // Buy Again button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/store');
            },
            icon: const Icon(Icons.shopping_cart_rounded, size: 18),
            label: const Text('Buy Again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    final List<Map<String, dynamic>> categories = [
      {
        'title': 'Post-UTME',
        'subtitle': 'Institution Specific',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF7C3AED), // Royal Purple to match Study tab
        'image': 'assets/images/post_utme.webp',
        'route': '/institution_selection',
        'examType': 'post_utme',
        'isAvailable': true,
      },
      {
        'title': 'JAMB',
        'subtitle': 'UTME Preparation',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF0D9488), // Sea Teal to match Study tab
        'image': 'assets/images/jamb.webp',
        'route': '/exam_dashboard',
        'examType': 'jamb',
        'isAvailable': false,
      },
      {
        'title': 'WAEC',
        'subtitle': 'SSCE Excellence',
        'icon': Icons.description_rounded,
        'color': const Color(0xFFF43F5E), // Rose Coral to match Study tab
        'image': 'assets/images/waec.webp',
        'route': '/exam_dashboard',
        'examType': 'waec',
        'isAvailable': false,
      },
      {
        'title': 'NECO',
        'subtitle': 'National Exams',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFF2563EB), // Cobalt Blue to match Study tab
        'image': 'assets/images/neco.webp',
        'route': '/exam_dashboard',
        'examType': 'neco',
        'isAvailable': false,
      },
    ];

    return SliverToBoxAdapter(
      child: TutorialService.instance.buildShowcase(
        key: TutorialService.instance.examSliderKey,
        title: 'Start Practicing 🎯',
        description: 'Choose your preferred exam category (JAMB, WAEC, NECO, or Post-UTME) to select subjects and start simulation!',
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Exam Categories',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Listener(
              onPointerDown: (_) => _stopAutoSlide(),
              onPointerUp: (_) => _startAutoSlide(),
              onPointerCancel: (_) => _startAutoSlide(),
              child: SizedBox(
                height: 120,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final cat = categories[index % categories.length];
                    final bool isAvailable = cat['isAvailable'] as bool? ?? false;

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () => _handleExamTap(context, cat),
                        borderRadius: BorderRadius.circular(20),
                        child: Opacity(
                          opacity: isAvailable ? 1.0 : 0.6,
                          child: Container(
                            width: 160,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: (cat['color'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (cat['color'] as Color).withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -10,
                                  bottom: -10,
                                  child: Opacity(
                                    opacity: 0.15,
                                    child: Image.asset(
                                      cat['image'],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                if (!isAvailable)
                                  const Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Icon(
                                      Icons.lock_outline_rounded,
                                      color: Colors.grey,
                                      size: 16,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        cat['icon'] as IconData,
                                        color: cat['color'] as Color,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        cat['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        isAvailable ? cat['subtitle'] : 'Coming soon',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isAvailable ? Colors.grey.shade500 : Colors.red.shade400,
                                          fontWeight: isAvailable ? null : FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}