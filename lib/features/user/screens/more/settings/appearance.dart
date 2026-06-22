import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart'; // Adjust path
import '../../../../../core/providers/app_theme_provider.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/hero_card.dart';

class Appearance extends StatelessWidget {
  const Appearance({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get the current theme from your provider
    final currentTheme = context.watch<AppThemeProvider>().themeMode;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Appearance',
                subtitle: 'Customize the visual theme of your app.',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HeroCard(
                        title: 'App Theme',
                        subTitle: 'Personalize your experience by selecting your preferred color mode.',
                        icon: Icons.palette_rounded,
                      ),
                      const SizedBox(height: 32),

                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            RadioListTile<ThemeMode>.adaptive(
                              value: ThemeMode.system,
                              // ignore: deprecated_member_use
                              groupValue: currentTheme,
                              // ignore: deprecated_member_use
                              onChanged: (ThemeMode? newValue) {
                                if (newValue != null) {
                                  context.read<AppThemeProvider>().setThemeMode(newValue);
                                }
                              },
                              title: const Text('System Default', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Matches your device settings'),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 18),
                              ),
                              activeColor: AppColors.primary,
                            ),

                            Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), height: 1),

                            RadioListTile<ThemeMode>.adaptive(
                              value: ThemeMode.light,
                              // ignore: deprecated_member_use
                              groupValue: currentTheme,
                              // ignore: deprecated_member_use
                              onChanged: (ThemeMode? newValue) {
                                if (newValue != null) {
                                  context.read<AppThemeProvider>().setThemeMode(newValue);
                                }
                              },
                              title: const Text('Light Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Bright and clear appearance'),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(Icons.light_mode_rounded, color: Colors.orange.shade700, size: 18),
                              ),
                              activeColor: AppColors.primary,
                            ),

                            Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), height: 1),

                            RadioListTile<ThemeMode>.adaptive(
                              value: ThemeMode.dark,
                              // ignore: deprecated_member_use
                              groupValue: currentTheme,
                              // ignore: deprecated_member_use
                              onChanged: (ThemeMode? newValue) {
                                if (newValue != null) {
                                  context.read<AppThemeProvider>().setThemeMode(newValue);
                                }
                              },
                              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Easy on the eyes in low light'),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(Icons.dark_mode_rounded, color: Colors.indigo.shade400, size: 18),
                              ),
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
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