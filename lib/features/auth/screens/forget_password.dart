import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';
import 'package:utme_pass_at_once/core/utils/custom_textfield.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import '../../../core/utils/custom_app_bar.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    // 1. Instantly dismiss the keyboard for smooth performance
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      CustomToast.show(context, 'Password reset link sent! Check your email.');
      Navigator.pop(context);
    } else {
      CustomToast.show(context, authProvider.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3. Cache the theme lookup to prevent redundant widget tree traversals
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const CustomAppBar(title: 'Forget Password', isLeading: true),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your email address to receive a password reset link.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        // Use color scheme for cleaner dynamic styling
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email TextField
                    CustomTextfield(
                      label: 'Email Address',
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                      suffixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 30),

                    // Send Reset Link Button (with loading state)
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        return CustomBtn(
                          label: auth.isLoading
                              ? 'Sending...'
                              : 'Send Reset Link',
                          backgroundColor: AppColors.primary,
                          onPressed:
                          auth.isLoading ? null : _handleSendResetLink,
                        );
                      },
                    ),
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