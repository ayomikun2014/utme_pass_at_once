import 'package:flutter/material.dart';
import '../../features/user/providers/news_provider.dart';
import '../constants/app_colors.dart';
import 'custom_btn.dart';

Widget buildErrorState(BuildContext context, NewsProvider provider) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Soft Circle Background with Icon
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white10 : AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Center(
              child: Icon(
                Icons.wifi_off_rounded, // Best icon for "No Signal"
                size: 50,
                color: Colors.blueGrey,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Connection Failed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Please check your internet or connect to the internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: 160,
            child: CustomBtn(
              label: 'Retry',
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
              onPressed: () {
                provider.loadNews(); // Trigger the fetch again
              },
            ),
          ),
        ],
      ),
    ),
  );
}