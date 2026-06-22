import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../../auth/providers/auth_provider.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor:
          isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(14, 32, 14, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'Log Out',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Are you sure you want to log out of your account?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: CustomBtn(
                  label: 'Cancel',
                  backgroundColor: Colors.transparent,
                  textColor: theme.colorScheme.onSurface,
                  borderColor: isDark
                      ? AppColors.dividerDark
                      : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  height: 48,
                  borderRadius: 12,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomBtn(
                  label: 'Yes, Log Out',
                  backgroundColor: AppColors.primary,
                  height: 48,
                  borderRadius: 12,
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    await authProvider.logout();

                    if (!context.mounted) return;

                    // Close dialog, then navigate to login clearing the stack
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}