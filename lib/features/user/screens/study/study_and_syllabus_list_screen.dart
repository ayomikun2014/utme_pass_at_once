import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../providers/syllabus_provider.dart';
import 'syllabus_pdf_viewer.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';

class StudyAndSyllabusListScreen extends StatefulWidget {
  final String examType; // e.g., 'jamb_syllabus', 'jamb_brochure', 'waec'
  final String title; // e.g., 'JAMB Syllabus'

  const StudyAndSyllabusListScreen({
    super.key,
    required this.examType,
    required this.title,
  });

  @override
  State<StudyAndSyllabusListScreen> createState() => _StudyAndSyllabusListScreenState();
}

class _StudyAndSyllabusListScreenState extends State<StudyAndSyllabusListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyllabusProvider>().fetchSyllabi(widget.examType);
    });
  }

  void _openPdf(dynamic syllabus) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyllabusPdfViewer(syllabus: syllabus),
      ),
    );
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
              onRefresh: () =>
                  context.read<SyllabusProvider>().syncFiles(widget.examType),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  CustomAppBar(
                    title: widget.title,
                    subtitle: 'Download and study offline securely.',
                    isLeading: true,
                    centerTitle: true,
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: Consumer<SyllabusProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const SliverFillRemaining(
                            child: Center(child: CustomLoader()),
                          );
                        }

                        if (provider.syllabi.isEmpty) {
                          return SliverFillRemaining(
                            child: _buildEmptyState(theme),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final syllabus = provider.syllabi[index];
                            final progress = provider.getProgressOf(syllabus.id);

                            return _buildPremiumSyllabusCard(
                              theme: theme,
                              isDark: isDark,
                              syllabus: syllabus,
                              progress: progress,
                              onTap: () {
                                if (syllabus.isDownloaded) {
                                  _openPdf(syllabus);
                                } else {
                                  provider.startDownload(syllabus, onComplete: () {
                                    _openPdf(syllabus);
                                  });
                                }
                              },
                            );
                          }, childCount: provider.syllabi.length),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildPremiumSyllabusCard({
    required ThemeData theme,
    required bool isDark,
    required dynamic syllabus,
    required double? progress,
    required VoidCallback onTap,
  }) {
    final isDownloading = progress != null && progress > 0 && progress < 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // --- Subject Icon ---
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Icon(
                    _getIconForSubject(syllabus.name),
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),

                // --- Text Content ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syllabus.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // --- Status Row ---
                      Row(
                        children: [
                          Icon(
                            syllabus.isDownloaded
                                ? Icons.check_circle_rounded
                                : Icons.file_download_outlined,
                            size: 14,
                            color: syllabus.isDownloaded
                                ? Colors.green
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isDownloading
                                  ? 'Downloading ${(progress * 100).toInt()}%'
                                  : (syllabus.isDownloaded
                                        ? 'Downloaded'
                                        : 'Available Online'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDownloading
                                    ? AppColors.primary
                                    : (syllabus.isDownloaded
                                          ? Colors.green
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // --- Action Subtitle (Directly underneath status) ---
                      Text(
                        isDownloading
                            ? 'Please wait...'
                            : (syllabus.isDownloaded
                                  ? 'Tap to open and study'
                                  : 'Tap to download securely'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Action Button / Progress Ring ---
                const SizedBox(width: 12),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Show progress ring ONLY if currently downloading
                      if (isDownloading) CustomLoader(color: AppColors.primary),
                      // Status Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: syllabus.isDownloaded
                              ? Colors.green.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          syllabus.isDownloaded
                              ? Icons.menu_book_rounded
                              : Icons.download_rounded,
                          size: 20,
                          color: syllabus.isDownloaded
                              ? Colors.green
                              : AppColors.primary,
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
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Syllabus Found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh and sync\nfiles from the server.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForSubject(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('math')) return Icons.calculate_outlined;
    if (lower.contains('english')) return Icons.book_rounded;
    if (lower.contains('bio')) return Icons.biotech_rounded;
    if (lower.contains('physic')) return Icons.bolt_rounded;
    if (lower.contains('chem')) return Icons.science_outlined;
    if (lower.contains('account')) return Icons.calculate_rounded;
    if (lower.contains('agric')) return Icons.agriculture_outlined;
    if (lower.contains('econ')) return Icons.bar_chart_rounded;
    return Icons.description_rounded;
  }
}
