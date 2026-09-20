import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../constants/app_colors.dart';

class CustomGridCard extends StatelessWidget {
  const CustomGridCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.route,
    required this.baseColor,
    this.icon,
    this.imagePath,
    this.arguments,
    this.onTap,
    this.requiresNetwork = false,
  });

  final String title;
  final String? subtitle;
  final String route;
  final Color baseColor;
  final IconData? icon;
  final String? imagePath;
  final Map<String, dynamic>? arguments;
  final VoidCallback? onTap;
  final bool requiresNetwork;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = isDark
        ? AppColors.surfaceDark
        : baseColor.withValues(alpha: 0.1);

    // Refined bubbles: softer in light mode, subtle brand tint in dark mode
    final bubbleColor = isDark
        ? baseColor.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () {
        if (requiresNetwork) {
          NetworkService.instance.runWithNetwork(context, () {
            if (onTap != null) {
              onTap!();
            } else {
              Navigator.pushNamed(context, route, arguments: arguments);
            }
          });
        } else {
          if (onTap != null) {
            onTap!();
          } else {
            Navigator.pushNamed(context, route, arguments: arguments);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: isDark ? Border.all(color: AppColors.dividerDark) : null,
          boxShadow: isDark
              ? null
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // bubble 1
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(radius: 40, backgroundColor: bubbleColor),
            ),

            // bubble 2
            Positioned(
              left: -30,
              bottom: -10,
              child: CircleAvatar(radius: 60, backgroundColor: bubbleColor),
            ),

            //Foreground content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: isDark
                          ? baseColor.withValues(alpha: 0.2)
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: isDark
                          ? []
                          : [
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: imagePath != null
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(imagePath!, fit: BoxFit.contain),
                          )
                        : Icon(icon, size: 24, color: baseColor),
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