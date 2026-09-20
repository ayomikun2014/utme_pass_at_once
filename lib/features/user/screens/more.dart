import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';

import '../../../core/utils/bg.dart';
import '../../../core/utils/custom_app_bar.dart';
import '../../../core/utils/custom_grid_card.dart';
import '../models/ui_grid_card_details.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class More extends StatelessWidget {
  const More({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          AnimationLimiter(
            child: CustomScrollView(
              slivers: [
              CustomAppBar(
                title: 'More Options',
                subtitle: 'Manage your account, preferences, and settings.',
                color: AppColors.dynamicColors[5].withValues(alpha: 0.90),
              ),
              _buildMoreFeatureCard(),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreFeatureCard() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final feature = moreFeatureList[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 600),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: CustomGridCard(
                  title: feature.title,
                  subtitle: feature.subtitle,
                  route: feature.route,
                  baseColor: feature.baseColor,
                  icon: feature.icon,
                  imagePath: feature.imagePath,
                  requiresNetwork: feature.requiresNetwork,
                ),
              ),
            ),
          );
        }, childCount: moreFeatureList.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1,
        ),
      ),
    );
  }
}
