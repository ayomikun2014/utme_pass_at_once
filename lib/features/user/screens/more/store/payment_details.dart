import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/features/user/models/store_item.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../providers/store_provider.dart';
import '../../../services/exam_coverage_service.dart';

class PaymentDetails extends StatefulWidget {
  const PaymentDetails({super.key});

  @override
  State<PaymentDetails> createState() => _PaymentDetailsState();
}

class _PaymentDetailsState extends State<PaymentDetails> {
  final ExamCoverageService _coverageService = ExamCoverageService();

  /// Held in state so the coverage is read once, not on every rebuild.
  Future<ExamCoverage>? _coverage;
  String? _coverageFor;

  Future<ExamCoverage> _coverageFuture(String examId) {
    if (_coverageFor != examId || _coverage == null) {
      _coverageFor = examId;
      _coverage = _coverageService.fetch(examId);
    }
    return _coverage!;
  }

  @override
  Widget build(BuildContext context) {
    final item = context.watch<StoreProvider>().selectedItem;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('No item selected. Please go back to the store.'),
        ),
      );
    }
    return Scaffold(
      bottomSheet: _bottomBuyButton(context, item),
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              _sliverAppBarHeader(item: item, context: context),
              _sliverBody(context: context),
            ],
          ),
        ],
      ),
    );
  }

  // --- APP BAR HEADER ---
  Widget _sliverAppBarHeader({
    required StoreItem? item,
    required BuildContext context,
  }) {
    if (item == null) {
      return SliverToBoxAdapter(
        child: Center(child: Text("Item not found. Please go back.")),
      );
    }
    return SliverAppBar(
      expandedHeight: 160,
      elevation: 0,
      floating: false,
      pinned: true,
      backgroundColor: item.baseColor.withValues(alpha: 0.2),

      // --- STANDARD BACK BUTTON ---
      leading: const BackButton(color: Colors.white),

      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate when the app bar collapses
          final top = constraints.biggest.height;
          final collapsedHeight =
              MediaQuery.of(context).padding.top + kToolbarHeight;
          final isCollapsed = top <= collapsedHeight + 15;

          return FlexibleSpaceBar(
            centerTitle: true,
            // --- TITLE WHEN COLLAPSED ---
            title: AnimatedOpacity(
              opacity: isCollapsed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                'Activation Code',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // --- EXPANDED BACKGROUND ---
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Image on the right side
                Positioned(
                  right: -20,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.25, // Subtle watermark effect
                    child: Image.asset(item.image, fit: BoxFit.contain),
                  ),
                ),

                // Dark Gradient Overlay (Bottom to Top)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),

                // Text Content at the bottom
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: isCollapsed ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activation Code - ${item.title}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color:
                                Colors.white, // Slightly faded for the subtitle
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // Formats price without decimal if it's a whole number (e.g., ₦1500)
                          '₦${item.price.toInt()}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Crisp white for the price
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CONTEXT (BODY) ----
  Widget _sliverBody({required BuildContext context}) {
    final item = context.watch<StoreProvider>().selectedItem!;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            _description(context: context, item: item),
            const SizedBox(height: 16),
            _buildAvailableSubjectsCard(context, item),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _description({
    required BuildContext context,
    required StoreItem item,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About this package",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            item.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAvailableSubjectsCard(BuildContext context, StoreItem item) {
    final theme = Theme.of(context);
    final primaryColor = item.baseColor;

    Widget buildSubjectBadge(String subject) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: primaryColor, size: 12),
            const SizedBox(width: 4),
            Text(
              subject,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildSectionTitle(String title, IconData icon) {
      return Row(
        children: [
          Icon(icon, color: primaryColor, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    Widget note(String text) => Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.4,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );

    IconData sectionIcon(String name) {
      final n = name.toLowerCase();
      if (n.contains('science')) return Icons.science_rounded;
      if (n.contains('art') || n.contains('commerce')) {
        return Icons.palette_rounded;
      }
      return Icons.library_books_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Package Coverage",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Here are the subjects and exam materials included in this activation package.",
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),

          // Read from the question bank, so the store lists exactly the
          // subjects that have questions behind them.
          FutureBuilder<ExamCoverage>(
            future: _coverageFuture(item.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return note(
                  'Could not load the subject list. Check your connection '
                  'and reopen this page.',
                );
              }

              final coverage = snapshot.data ?? const ExamCoverage();
              if (coverage.isEmpty) {
                return note(
                  'The subjects for this package are still being uploaded.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (coverage.institutions.isNotEmpty) ...[
                    buildSectionTitle(
                      "Supported Institutions",
                      Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: coverage.institutions.map((inst) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            inst,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (coverage.subjects.isNotEmpty) ...[
                    buildSectionTitle(
                      "Available Subjects",
                      Icons.library_books_rounded,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: coverage.subjects
                          .map(buildSubjectBadge)
                          .toList(),
                    ),
                  ],

                  for (final entry in coverage.sections.entries) ...[
                    buildSectionTitle(
                      '${entry.key} Section',
                      sectionIcon(entry.key),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.value.map(buildSubjectBadge).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- BOTTOM SHEET ---
  Widget _bottomBuyButton(BuildContext context, StoreItem? item) {
    if (item == null) return const SizedBox();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Safety check for stock status
    final bool isOutOfStock = item.isOutOfStock == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Theme-aware background
        color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
        // In Dark mode, shadows look muddy. We use a subtle top border instead.
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : Colors.transparent,
          ),
        ),
        boxShadow: [
          // Only show shadow in light mode
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
        ],
      ),
      child: SafeArea(
        child: CustomBtn(
          // Change label based on stock status
          label: isOutOfStock
              ? "Coming Soon"
              : "Buy Now - ₦${item.price.toInt()}",

          // Grey out the background if out of stock
          backgroundColor: isOutOfStock
              ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
              : item.baseColor,

          // Dim the text if out of stock
          textColor: isOutOfStock
              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
              : Colors.white,

          // Disable the button by passing null to onPressed when out of stock
          onPressed: isOutOfStock
              ? null // Disables the button completely
              : () {
                  Navigator.pushNamed(context, '/select_payment');
                },
        ),
      ),
    );
  }
}
