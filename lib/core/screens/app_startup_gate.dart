import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../utils/version_helper.dart';
import '../../features/auth/screens/auth_gate.dart';
import 'maintenance_screen.dart';
import 'force_update_screen.dart';

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        // 1. Loading State (Now using the custom animated logo)
        if (settings.isLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: _PulsingLogo(),
            ),
          );
        }

        // 2. Check Maintenance Mode
        if (settings.maintenanceMode) {
          return const MaintenanceScreen();
        }

        // 3. Check App Version
        final installed = settings.installedVersion;
        final min = settings.minAppVersion;
        final latest = settings.latestAppVersion; // FIXED: Renamed

        // Force Update Rules
        bool isBelowMin = VersionHelper.isLessThan(installed, min);
        bool isForcedByLatest = settings.forceUpdate && VersionHelper.isLessThan(installed, latest);

        if (isBelowMin || isForcedByLatest) {
          return const ForceUpdateScreen();
        }

        // Optional Update Logic
        // FIXED: Now respects the 'showUpdatePrompt' toggle from Admin Panel!
        if (!_dialogShown && settings.showUpdatePrompt && VersionHelper.isLessThan(installed, latest)) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOptionalUpdateDialog(context, settings);
            }
          });
        }

        // 4. Continue to normal app flow
        return const AuthGate();
      },
    );
  }

  void _showOptionalUpdateDialog(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(
          settings.updateTitle.isNotEmpty ? settings.updateTitle : 'New Version Available',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          settings.updateMessage.isNotEmpty ? settings.updateMessage : 'A new version of the app is available. Would you like to update?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () async {
              Navigator.pop(context);
              String url = '';
              if (Platform.isAndroid) {
                url = settings.androidUpdateUrl.isNotEmpty ? settings.androidUpdateUrl : settings.playStoreUrl;
              } else if (Platform.isIOS) {
                url = settings.iosUpdateUrl.isNotEmpty ? settings.iosUpdateUrl : settings.appStoreUrl;
              }
              if (url.isNotEmpty) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CUSTOM ANIMATED LOADING LOGO
// ─────────────────────────────────────────────────────────────
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1-second breathing loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // GPU-accelerated scaling (breathes from 85% to 100% size)
        return Transform.scale(
          scale: 0.85 + (_controller.value * 0.15),
          child: Image.asset(
            'assets/images/app_logo.webp',
            width: 100,
            height: 100,
          ),
        );
      },
    );
  }
}