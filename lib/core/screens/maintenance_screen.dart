import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 80,
                  color: theme.colorScheme.primary, // Dynamic theme color
                ),
                const SizedBox(height: 24),
                Text(
                  'App Under Maintenance',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface, // Replaced ternary logic
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We are improving the app. Please check back later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 32),
                if (settings.contactEmail.isNotEmpty || settings.supportPhones.isNotEmpty) ...[
                  Divider(color: theme.dividerColor),
                  const SizedBox(height: 16),
                  Text(
                    'Need urgent help?',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (settings.contactEmail.isNotEmpty)
                    Text(settings.contactEmail, style: theme.textTheme.bodyMedium),
                  if (settings.primaryPhone != null)
                    Text(settings.primaryPhone!.phoneNumber, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}