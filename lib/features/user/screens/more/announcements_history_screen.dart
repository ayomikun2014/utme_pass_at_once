import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_loader.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/utils/custom_toast.dart';
import '../../providers/announcement_provider.dart';
import '../../../../routes.dart';

class AnnouncementsHistoryScreen extends StatefulWidget {
  const AnnouncementsHistoryScreen({super.key});

  @override
  State<AnnouncementsHistoryScreen> createState() => _AnnouncementsHistoryScreenState();
}

class _AnnouncementsHistoryScreenState extends State<AnnouncementsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnnouncementProvider>().fetchAnnouncements();
    });
  }

  Future<void> _handleRefresh() async {
    final hasInternet = NetworkService.instance.isOnline;
    if (!hasInternet) {
      CustomToast.show(context, 'No internet connection. Failed to refresh.', isError: true);
      return;
    }
    await context.read<AnnouncementProvider>().fetchAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              slivers: [
                const CustomAppBar(
                  title: 'Announcements',
                  subtitle: 'Stay updated with official news and portals.',
                  isLeading: true,
                  centerTitle: true,
                ),
                Consumer<AnnouncementProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.announcements.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CustomLoader(),
                        ),
                      );
                    }

                    if (provider.announcements.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.campaign_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Announcements Yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Check back later for official news and updates.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final announcement = provider.announcements[index];
                            final formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                                .format(announcement.createdAt);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.notificationDetails,
                                    arguments: {
                                      'title': announcement.title,
                                      'body': announcement.description,
                                      'type': 'broadcast',
                                      'createdAt': announcement.createdAt.toIso8601String(),
                                      'payload': {
                                        'route': '/announcements',
                                      }
                                    },
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.campaign_outlined,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              announcement.title,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              formattedDate,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: provider.announcements.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
