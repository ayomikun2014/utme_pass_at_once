import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../../core/providers/settings_provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_btn.dart';

class Rate extends StatelessWidget {
  const Rate({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Rate Us',
                subtitle:
                    'Love using our app? Let us know your thoughts and help us improve.',
                color: AppColors.primary,
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 50),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                      ),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.05,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 5 Stars Display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Icon(
                                Icons.star_rounded, // Solid star icon
                                color: Colors.amber,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // The Message
                        Text(
                          'If PASS AT ONCE CBT is helping you crush your studies and prepare for your exams, please consider leaving us a 5-star review.\n\nIt only takes a few seconds, and it helps us reach and support more students just like you!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- YOUR CUSTOM BUTTON ---
                        CustomBtn(
                          label: 'Rate 5 Stars',
                          icon: Icons.star_outline_rounded,
                          backgroundColor: AppColors.primary,
                          height: 54,
                          borderRadius: 16,
                          onPressed: () async {
                            final InAppReview inAppReview =
                                InAppReview.instance;
                            try {
                              if (await inAppReview.isAvailable()) {
                                await inAppReview.requestReview();
                              } else {
                                if (!context.mounted) return;
                                final settings = context.read<SettingsProvider>().settings;
                                final String storeUrl = Platform.isIOS ? settings.appStoreUrl : settings.playStoreUrl;

                                if (storeUrl.isNotEmpty) {
                                  final Uri url = Uri.parse(storeUrl);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                CustomToast.show(context,
                                      'Could not open rating page.',
                                    );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
