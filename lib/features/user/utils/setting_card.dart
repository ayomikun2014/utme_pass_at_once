import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

Widget buildSettingCard({
  required BuildContext context,
  required String title,
  required IconData icon,
  String? route, // other routes
  VoidCallback? onTap, // for logout
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // FIXED: Using Flutter's native theme color instead of hardcoded AppColors
  final textColor = theme.colorScheme.onSurface;

  return GestureDetector(
    onTap: () {
      if (onTap != null) {
        onTap();
      } else if (route != null) {
        Navigator.pushNamed(context, route);
      }
    },
    child: Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: textColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: textColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    ),
  );
}