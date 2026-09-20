import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:provider/provider.dart';
import '../../../../../core/utils/app_update.dart';
import 'dart:io';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../providers/simulator_provider.dart';
import '../../../services/simulator_service.dart';
import '../../../utils/activation_bottom_sheet.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String _deviceId = '--';
  String _lastUpdated = 'Not synced yet';
  bool _isUpToDate = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      setState(() {
        _deviceId = authProvider.currentDeviceId;
      });
      // Retrieve last updated date from local storage or set initial mock state
    });
  }

  bool _isVersionNewer(String installed, String latest) {
    String cleanVersion(String v) {
      final idx = v.indexOf(RegExp(r'[-+]'));
      if (idx != -1) {
        return v.substring(0, idx).trim();
      }
      return v.trim();
    }

    final cleanInstalled = cleanVersion(installed);
    final cleanLatest = cleanVersion(latest);

    final installedParts = cleanInstalled
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final latestParts = cleanLatest
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    final maxLen = installedParts.length > latestParts.length
        ? installedParts.length
        : latestParts.length;

    for (int i = 0; i < maxLen; i++) {
      final installedPart = i < installedParts.length ? installedParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      if (latestPart > installedPart) return true;
      if (latestPart < installedPart) return false;
    }
    return false;
  }

  Future<void> _handleUpdateQuestions() async {
    final simProvider = context.read<SimulatorProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      CustomToast.show(context, 'Please log in to update questions.');
      return;
    }

    // 1. Show checking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.surfaceDark
              : theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 50, height: 50, child: CustomLoader()),
              const SizedBox(height: 24),
              Text(
                "Checking for updates...",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Please wait while we sync with the server.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    try {
      bool updatesFound = false;
      final isFreeUser = !user.isPremiumOnDevice(_deviceId);

      // --- FREE USER: Re-sync free questions ---
      if (isFreeUser) {
        await SimulatorService().predownloadFreeQuestions();
        if (!mounted) return;
        Navigator.pop(context);
        CustomToast.show(context, 'Free questions synced successfully!');
        setState(() {
          _isUpToDate = true;
          _lastUpdated = 'Just now';
        });
        return;
      }

      // 2. Iterate through all active exam types to check for updates (force checks from server)
      final activeExams = ['post_utme', 'waec', 'jamb', 'neco'];

      for (final exam in activeExams) {
        if (user.hasActiveExam(exam, _deviceId)) {
          final centers = user.getExamCenters(exam);

          for (final center in centers) {
            final section = user.getSectionForInstitution(exam, center);
            final baseInstitutionId =
                exam == 'post_utme' && center.contains('_')
                ? center.split('_').first
                : center;

            // Call the Smart Merge check (force = true to check server updates)
            final updateInfo = await simProvider.checkForUpdates(
              examType: exam,
              institutionId: baseInstitutionId,
              sectionId: section?['id'],
              force: true,
            );

            if (updateInfo['updatesAvailable'] == true) {
              updatesFound = true;

              if (!mounted) return;
              Navigator.pop(context); // Close checking dialog

              // 3. Download the delta updates with force: true to overwrite modifications
              final downloadFuture = simProvider.downloadActivationData(
                examType: exam,
                institutionId: baseInstitutionId,
                subjects: user.getSubjectsForCenter(exam, center),
                sectionId: section?['id'],
                force: true,
              );

              await showModalBottomSheet(
                context: context,
                isDismissible: false,
                enableDrag: false,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => ActivationBottomSheet(
                  task: () => downloadFuture,
                  isUpdateFlow: true,
                  onComplete: () {
                    // Sheet popped itself upon success confirmation
                  },
                ),
              );
              break; // Break the inner loop, continue checking other exams
            }
          }
        }
      }

      if (!mounted) return;

      // If checking dialog is still open (no updates found), close it
      if (!updatesFound) {
        Navigator.pop(context);
        CustomToast.show(context, 'All questions are already up-to-date!');
        setState(() {
          _isUpToDate = true;
          _lastUpdated = 'Just now';
        });
      } else {
        setState(() {
          _isUpToDate = true;
          _lastUpdated = 'Just now';
        });
        CustomToast.show(context, 'Update completed successfully!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close checking dialog on error
        CustomToast.show(context, 'Update failed: $e', isError: true);
      }
    }
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: _deviceId));
    CustomToast.show(context, 'Device ID copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsProvider = context.watch<SettingsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isFreeUser = user == null || !user.isPremiumOnDevice(_deviceId);

    final installed = settingsProvider.installedVersion;
    final latest = settingsProvider.latestAppVersion;
    final appUpdateAvailable = _isVersionNewer(installed, latest);
    final storeUrl = Platform.isIOS
        ? settingsProvider.appStoreUrl
        : settingsProvider.playStoreUrl;

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const CustomAppBar(
                title: 'App Updates',
                subtitle: 'Manage and sync your application state.',
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
                      // Circular sync status illustration
                      _buildSyncStatusIndicator(
                        appUpdateAvailable,
                        isDark,
                        theme,
                      ),

                      // Questions database card
                      _buildDatabaseSyncCard(
                        context,
                        isFreeUser,
                        isDark,
                        theme,
                      ),
                      const SizedBox(height: 16),

                      // App version card
                      _buildAppUpdateCard(
                        context,
                        installed,
                        latest,
                        storeUrl,
                        isDark,
                        theme,
                      ),
                      const SizedBox(height: 16),

                      // Device activation info card
                      _buildDeviceInfoCard(context, isDark, theme),
                      const SizedBox(height: 40),
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

  Widget _buildSyncStatusIndicator(
    bool appUpdateAvailable,
    bool isDark,
    ThemeData theme,
  ) {
    final statusColor = appUpdateAvailable ? Colors.orange : Colors.green;
    return Column(
      children: [
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing ring
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.05),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.1),
                  width: 4,
                ),
              ),
            ),
            // Middle pulsing ring
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.15),
                  width: 3,
                ),
              ),
            ),
            // Inner solid circle with gradient
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: appUpdateAvailable
                      ? [Colors.orange.shade400, Colors.deepOrange.shade600]
                      : [Colors.green.shade400, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                appUpdateAvailable
                    ? Icons.system_update_alt_rounded
                    : Icons.cloud_done_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          appUpdateAvailable ? 'Updates Available' : 'Your App is Up to Date',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            appUpdateAvailable
                ? 'A newer version of the app is available on the store.'
                : 'Everything is synced and ready for offline use.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAppUpdateCard(
    BuildContext context,
    String installed,
    String latest,
    String storeUrl,
    bool isDark,
    ThemeData theme,
  ) {
    final hasUpdate = _isVersionNewer(installed, latest);
    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hasUpdate ? Colors.orange : theme.colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  color: hasUpdate ? Colors.orange : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Version',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUpdate
                          ? 'New version available'
                          : 'You are on the latest version',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasUpdate
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (hasUpdate ? Colors.orange : Colors.green).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasUpdate ? 'UPDATE' : 'LATEST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasUpdate
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installed',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v$installed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Latest Release',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v$latest',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            // The shared helper, so this button and the update overlay behave
            // the same -- including falling back to the store listing when no
            // link has been set in admin settings.
            onPressed: () =>
                launchAppUpdate(context, context.read<SettingsProvider>()),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              hasUpdate ? 'Update App on Play Store' : 'Open Play Store',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseSyncCard(
    BuildContext context,
    bool isFreeUser,
    bool isDark,
    ThemeData theme,
  ) {
    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isFreeUser ? Colors.red : Colors.blue).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFreeUser
                      ? Icons.lock_outline_rounded
                      : Icons.storage_rounded,
                  color: isFreeUser ? Colors.red : Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Questions Database',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFreeUser
                          ? 'Unlock premium to sync latest questions offline'
                          : (_isUpToDate
                                ? 'Offline content is up-to-date'
                                : 'Sync pending check'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isFreeUser
                            ? Colors.red.shade700
                            : (_isUpToDate
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Sync Status',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFreeUser ? 'Inactive' : _lastUpdated,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Consumer<SimulatorProvider>(
            builder: (context, simProvider, child) {
              final isChecking = simProvider.isCheckingUpdates;
              return ElevatedButton.icon(
                onPressed: isChecking
                    ? null
                    : () {
                        if (isFreeUser) {
                          Navigator.pushNamed(context, '/store');
                        } else {
                          _handleUpdateQuestions();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFreeUser
                      ? Colors.red
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: isFreeUser
                    ? const Icon(Icons.lock_open_rounded, size: 18)
                    : (isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 18)),
                label: Text(
                  isFreeUser
                      ? 'Unlock Premium to Sync'
                      : (isChecking
                            ? 'Checking Updates...'
                            : 'Check & Sync Questions'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offline Activation Info',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'To access mock exams offline without internet, ensure you fully download activation packages first. Your offline database is unique to this device.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Device ID',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _deviceId,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _copyDeviceId,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Copy ',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Icon(Icons.copy_rounded, size: 12, color: Colors.red),
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
