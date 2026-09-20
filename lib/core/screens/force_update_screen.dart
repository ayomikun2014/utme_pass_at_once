import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../../core/utils/app_update.dart';
import 'app_notice_screen.dart';

/// The update wall shown at startup, before any screen exists to sit under.
///
/// The same notice the in-app overlay uses, so an update looks the same
/// whether the app catches it on launch or while someone is reading.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return AppNoticeScreen(
      title: settings.updateTitle.isNotEmpty
          ? settings.updateTitle
          : 'Update Required',
      message: settings.updateMessage.isNotEmpty
          ? settings.updateMessage
          : 'A new version of the app is required to continue. '
                'Please update now.',
      actionLabel: 'Update',
      onAction: () => launchAppUpdate(context, settings),
      footnote: 'Required update',
    );
  }
}
