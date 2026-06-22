import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/features/user/models/store_item.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../providers/store_provider.dart';

class PaymentDetails extends StatefulWidget {
  const PaymentDetails({super.key});

  @override
  State<PaymentDetails> createState() => _PaymentDetailsState();
}

class _PaymentDetailsState extends State<PaymentDetails> {
  int selectedIndex = 0;

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
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            // --- TAB BAR ---
            Container(
              height: 50,
              padding: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  _tabItem(title: 'Description', index: 0),
                  _tabItem(title: 'Features', index: 1),
                ],
              ),
            ),

            // ---CONTENT---
            _tabContent(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- TAB ITEM ---
  Widget _tabItem({required String title, required int index}) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedIndex = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? theme.scaffoldBackgroundColor
                  : theme.hintColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContent() {
    if (selectedIndex == 0) {
      return _description(
        context: context,
        item: context.watch<StoreProvider>().selectedItem!,
      );
    } else {
      return _features(
        context: context,
        item: context.watch<StoreProvider>().selectedItem!,
      );
    }
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _features({required BuildContext context, required StoreItem item}) {
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
            "Key Features",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          ...item.features.map(
            (feature) =>
                _featureItem(context, feature.title, feature.description),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _featureItem(BuildContext context, String title, String description) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: AppColors.primary, size: 18),
          ),

          const SizedBox(width: 12),

          /// Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
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
