import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:utme_pass_at_once/core/utils/custom_loader.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/bg.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../providers/simulator_provider.dart';
import '../../../utils/activation_bottom_sheet.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String _deviceId = '--';
  String _lastUpdated = '--';
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
      // You can fetch the actual last updated date from SharedPreferences or Hive here later
    });
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
          backgroundColor: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CustomLoader(),
              ),
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

      // 2. Iterate through all active exam types to check for updates
      final activeExams = ['post_utme', 'waec', 'jamb', 'neco'];

      for (final exam in activeExams) {
        if (user.hasActiveExam(exam, _deviceId)) {
          final centers = user.getExamCenters(exam);

          for (final center in centers) {
            final section = user.getSectionForInstitution(exam, center);
            final baseInstitutionId = exam == 'post_utme' && center.contains('_')
                ? center.split('_').first
                : center;

            // Call the Smart Merge check we built in SimulatorService
            final updateInfo = await simProvider.checkForUpdates(
              examType: exam,
              institutionId: baseInstitutionId,
              sectionId: section?['id'],
            );

            if (updateInfo['updatesAvailable'] == true) {
              updatesFound = true;

              if (!mounted) return;
              Navigator.pop(context); // Close checking dialog

              // 3. Download the delta updates
              final downloadFuture = simProvider.downloadActivationData(
                examType: exam,
                institutionId: baseInstitutionId,
                sectionId: section?['id'],
              );

              await showModalBottomSheet(
                context: context,
                isDismissible: false,
                enableDrag: false,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => ActivationBottomSheet(
                  task: () => downloadFuture,
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

      // If the checking dialog is still open (no updates found), close it
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

    return Scaffold(
      body: Stack(
        children: [
          const BlobBackground(),
          CustomScrollView(
            slivers: [
              const CustomAppBar(
                title: 'Updates',
                subtitle: 'Keep your offline questions up to date.',
                isLeading: true,
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      // VERSION TEXT
                      Builder(
                        builder: (context) {
                          final settingsProvider = context.watch<SettingsProvider>();
                          final installed = settingsProvider.installedVersion;
                          final latest = settingsProvider.latestAppVersion;

                          return Column(
                            children: [
                              Center(
                                child: Text(
                                  '$installed v',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              if (installed != latest) ...[
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    'Latest: $latest',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // MAIN UPDATE CARD
                      _buildUpdateCard(theme, isDark),

                      const SizedBox(height: 16),

                      // FOOTER
                      Center(
                        child: Text(
                          'Ensure you have a stable internet connection to update questions',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
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

  Widget _buildUpdateCard(ThemeData theme, bool isDark) {
    final bgColor = isDark ? AppColors.surfaceDark : theme.colorScheme.surface;
    final borderColor = isDark
        ? AppColors.dividerDark
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Update Questions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Click the button below to update new questions into your app.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Update Button
          Consumer<SimulatorProvider>(
              builder: (context, simProvider, child) {
                return ElevatedButton.icon(
                  onPressed: simProvider.isCheckingUpdates ? null : _handleUpdateQuestions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? theme.colorScheme.primary : Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  label: const Text(
                    'Update Questions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 20),
                );
              }
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          const Text(
            'Last updated',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastUpdated,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isUpToDate ? 'All questions are up-to-date.' : 'All questions are not up-to-date.',
            style: TextStyle(
              fontSize: 14,
              color: _isUpToDate ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(height: 32),

          // Device ID Section
          const Text(
            'Device ID',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _deviceId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _copyDeviceId,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Copy ',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Icon(Icons.copy_rounded, size: 14, color: Colors.red),
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