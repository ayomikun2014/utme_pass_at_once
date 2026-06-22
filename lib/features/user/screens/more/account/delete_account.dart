import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/custom_app_bar.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../../../core/utils/custom_textfield.dart';
import '../../../../auth/providers/auth_provider.dart';

class DeleteAccount extends StatefulWidget {
  const DeleteAccount({super.key});

  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    final authProvider = context.read<AuthProvider>();
    final isGoogle = authProvider.isGoogleUser;

    if (!isGoogle) {
      if (!_formKey.currentState!.validate()) return;
    }

    // Secure two-step confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Confirm Deletion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you absolutely sure you want to delete your account? This will permanently and irreversibly erase all your study history, assignments, eClassroom logs, and active premium subscriptions. This action is final.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await authProvider.deleteAccount(
      password: isGoogle ? null : _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Account deleted — navigate to login clearing the stack
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );

      CustomToast.show(context, 'Account deleted successfully.');
    } else {
      CustomToast.show(context, authProvider.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color dangerColor = Colors.red.shade600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // --- FIXED BOTTOM BUTTON ---
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.dividerDark
                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return CustomBtn(
              label: auth.isLoading ? 'Deleting...' : 'Delete My Account',
              icon: Icons.delete_forever_rounded,
              backgroundColor: dangerColor,
              height: 54,
              borderRadius: 16,
              onPressed: auth.isLoading ? null : _handleDeleteAccount,
            );
          },
        ),
      ),

      body: CustomScrollView(
        slivers: [
          const CustomAppBar(title: 'Delete Account', isLeading: true),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- WARNING ICON ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: dangerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_rounded,
                          color: dangerColor, size: 48),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'This action is irreversible. All your mock exam history, saved questions, and premium subscription status will be permanently erased.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- CONFIRMATION INPUT ---
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.isGoogleUser) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'To confirm, you will be prompted to re-authenticate with your Google account:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.g_mobiledata_rounded, color: theme.colorScheme.primary, size: 40),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Re-authentication is required securely by Google Play and Firebase to verify your identity before account erasure.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'To confirm, please enter your password:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              CustomTextfield(
                                label: 'Password',
                                hintText: 'Enter your password',
                                controller: _passwordController,
                                obscureText: true,
                                enablePasswordToggle: true,
                                keyboardType: TextInputType.visiblePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required to delete account';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}