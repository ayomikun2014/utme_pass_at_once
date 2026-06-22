import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/custom_btn.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _launchUpdateUrl(BuildContext context, SettingsProvider settings) async {
    String url = '';
    if (Platform.isAndroid) {
      url = settings.androidUpdateUrl.isNotEmpty ? settings.androidUpdateUrl : settings.playStoreUrl;
    } else if (Platform.isIOS) {
      url = settings.iosUpdateUrl.isNotEmpty ? settings.iosUpdateUrl : settings.appStoreUrl;
    }

    if (url.isEmpty) {
      CustomToast.show(context, 'Update link not available', isError: true);
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      CustomToast.show(context, 'Could not open update link', isError: true);
    }
  }

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
                  Icons.system_update_rounded,
                  size: 80,
                  color: theme.colorScheme.primary, // Fixed color
                ),
                const SizedBox(height: 24),
                Text(
                  settings.updateTitle.isNotEmpty ? settings.updateTitle : 'Update Available',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  settings.updateMessage.isNotEmpty
                      ? settings.updateMessage
                      : 'A new version of the app is available. Please update to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5), // Fixed styling
                ),
                const SizedBox(height: 32),
                CustomBtn(
                  label: 'Update Now',
                  backgroundColor: theme.colorScheme.primary,
                  onPressed: () => _launchUpdateUrl(context, settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}