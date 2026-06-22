import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/bg.dart';
import '../../../../core/utils/custom_app_bar.dart';
import '../../../../core/utils/custom_loader.dart';
import '../../models/store_item.dart';
import '../../providers/store_provider.dart';
import '../../../../core/providers/settings_provider.dart';

class Store extends StatelessWidget {
  const Store({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                icon: null,
                title: 'Store',
                subtitle:
                'Unlock premium bundles, past questions, and study materials to guarantee your success.',
                isLeading: true,
              ),
              _buildStoreCard(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    if (settingsProvider.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CustomLoader(),
          ),
        ),
      );
    }

    final cards = getStoreCards(settingsProvider.settings);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = cards[index];
          return _buildStoreContainer(context: context, item: item);
        }, childCount: cards.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
      ),
    );
  }

  Widget _buildStoreContainer({
    required BuildContext context,
    required StoreItem item,
  }) {
    final theme = Theme.of(context); //
    final isDark = theme.brightness == Brightness.dark; //
    final bool isSoon = item.isOutOfStock;

    return GestureDetector(
      onTap: isSoon
          ? () {
        CustomToast.show(context, 
              '${item.title} is coming soon! We are currently uploading the latest questions.',
            );
      }
          : () {
        context.read<StoreProvider>().selectItem(item);
        Navigator.pushNamed(context, '/payment_details');
      },
      child: Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isDark
              ? (isSoon ? Colors.grey.shade900 : AppColors.surfaceDark)
              : (isSoon
              ? Colors.grey.shade100
              : item.baseColor.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? (isSoon ? Colors.grey.shade800 : AppColors.dividerDark)
                : (isSoon
                ? Colors.grey.shade300
                : item.baseColor.withValues(alpha: 0.3)),
            width: 1.5,
          ),
          boxShadow: isSoon
              ? []
              : [
            BoxShadow(
              color: item.baseColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Opacity(
                opacity: isSoon ? 0.08 : 0.15,
                child: Image.asset(
                  item.image,
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1.1,
                      // FIXED: Using theme.colorScheme.onSurface for dynamic text
                      color: isSoon
                          ? Colors.grey
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSoon ? Colors.grey.shade400 : item.baseColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSoon
                          ? []
                          : [
                        BoxShadow(
                          color: item.baseColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSoon)
                          const Icon(Icons.lock_clock_outlined,
                              size: 14, color: Colors.white),
                        if (isSoon) const SizedBox(width: 6),
                        Text(
                          isSoon ? 'Coming Soon' : 'Buy Now',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}