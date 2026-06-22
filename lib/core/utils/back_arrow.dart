import 'package:flutter/material.dart';

Widget backArrow({
  required ThemeData theme,
  required BuildContext context,
  VoidCallback? onPressed,
}) {
  return Padding(
    padding: const EdgeInsets.all(
      6.0,
    ), // Tighter padding fits the AppBar better
    child: Container(
      width: 32, // Reduced container size
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Premium transparent primary color background
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(), // Remove default constraints
        onPressed:
            onPressed ??
            () {
              // Safety check to prevent crashing if it's the first screen
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 15, // Slightly larger icon within a smaller container
          color: theme.colorScheme.primary, // Matches the premium UI
        ),
      ),
    ),
  );
}
