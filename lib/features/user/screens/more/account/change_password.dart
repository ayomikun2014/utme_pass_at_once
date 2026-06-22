import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/utils/custom_app_bar.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/custom_btn.dart';
import '../../../../../core/utils/custom_textfield.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Clear fields on success
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      CustomToast.show(context, 'Password updated successfully!');

      // Return to previous screen after success
      Navigator.pop(context);
    } else {
      CustomToast.show(context, authProvider.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // --- FIXED BOTTOM BUTTON AREA ---
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.dividerDark
                  : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return CustomBtn(
              label: auth.isLoading ? 'Saving...' : 'Save Changes',
              backgroundColor: AppColors.primary,
              height: 54,
              borderRadius: 16,
              onPressed: auth.isLoading ? null : _handleChangePassword,
            );
          },
        ),
      ),

      // --- SCROLLABLE CONTENT ---
      body: CustomScrollView(
        slivers: [
          const CustomAppBar(title: 'Change Password', isLeading: true),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CURRENT PASSWORD ---
                    _buildPasswordField(
                      label: 'Current Password',
                      hintText: 'Enter your current Password',
                      controller: _currentPasswordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- NEW PASSWORD ---
                    _buildPasswordField(
                      label: 'New Password',
                      hintText: 'Create New Password',
                      controller: _newPasswordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- CONFIRM PASSWORD ---
                    _buildPasswordField(
                      label: 'Confirm Password',
                      hintText: 'Confirm New Password',
                      controller: _confirmPasswordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
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

  Widget _buildPasswordField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return CustomTextfield(
      label: label,
      hintText: hintText,
      controller: controller,
      obscureText: true,
      enablePasswordToggle: true,
      validator: validator,
      keyboardType: TextInputType.visiblePassword,
    );
  }
}