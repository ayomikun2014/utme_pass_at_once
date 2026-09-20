import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_btn.dart';

class ShareApp extends StatelessWidget {
  const ShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settings = context.watch<SettingsProvider>().settings;
    final String appLink = settings.shareLink.isNotEmpty 
        ? settings.shareLink 
        : (Platform.isIOS ? settings.appStoreUrl : settings.playStoreUrl);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Share App',
                subtitle:
                    'Invite your friends to study smarter and pass their exams.',
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
                        // Icon Display
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons
                                .people_alt_rounded, // Group icon for sharing/community
                            color: AppColors.primary,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // The Message
                        Text(
                          'Learning is Better Together! 🚀',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Don\'t keep the secret to yourself! Invite your friends to join PASS AT ONCE CBT. Challenge each other, compare mock scores, and conquer your exams as a team.',
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

                        // --- PRIMARY ACTION: SHARE VIA ---
                        CustomBtn(
                          label: 'Share with Friends',
                          icon: Icons.send_rounded,
                          backgroundColor: AppColors.primary,
                          height: 54,
                          borderRadius: 16,
                          onPressed: () {
                            Share.share(
                              'Hey! Check out PASS AT ONCE CBT, the ultimate app for acing your exams! 🚀\n\nDownload here: $appLink',
                              subject: 'PASS AT ONCE CBT - Exam Success',
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // --- SECONDARY ACTION: COPY LINK (Outlined Button) ---
                        CustomBtn(
                          label: 'Copy App Link',
                          icon: Icons.copy_rounded,
                          // Make the background transparent for an outlined look
                          backgroundColor: Colors.transparent,
                          // Use the theme text color so it looks good in Dark and Light mode
                          textColor: theme.colorScheme.onSurface,
                          borderColor: isDark
                              ? AppColors.dividerDark
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                          height: 54,
                          borderRadius: 16,
                          onPressed: () async {
                            // Copies the link to the user's clipboard!
                            await Clipboard.setData(
                              ClipboardData(text: appLink),
                            );
                            if (!context.mounted) return;
                            CustomToast.show(context,
                                  'App link copied to clipboard!',
                                );
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
