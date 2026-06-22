import 'package:flutter/material.dart';

class CustomBtn extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double borderRadius;
  final IconData? icon;

  const CustomBtn({
    super.key,
    required this.label,
    this.backgroundColor,
    required this.onPressed,
    this.borderColor,
    this.textColor,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color effectiveBgColor = backgroundColor ?? theme.colorScheme.primary;

    Color effectiveTextColor = textColor ?? Colors.white;
    if (isDark && textColor == Colors.black) {
      effectiveTextColor = Colors.white;
    }

    Color? effectiveBorderColor = borderColor;
    if (isDark && borderColor == Colors.black) {
      effectiveBorderColor = Colors.white;
    }

    return Container(
      width: width ?? double.infinity,
      height: height ?? 50,
      decoration: BoxDecoration(
        color: onPressed == null
            ? effectiveBgColor.withValues(alpha: 0.5)
            : effectiveBgColor,
        border: effectiveBorderColor != null
            ? Border.all(color: effectiveBorderColor, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: effectiveTextColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: effectiveTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}