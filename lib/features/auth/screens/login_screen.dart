import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';
import 'package:utme_pass_at_once/core/utils/custom_textfield.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (message.toLowerCase().contains('suspended')) {
      _showSuspendedDialog(message);
    } else {
      CustomToast.show(context, message, isError: true);
    }
  }

  void _showSuspendedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap Okay
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, color: Colors.red, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Account Suspended',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                message.replaceAll('Your account has been suspended by the admin.\n', ''),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Okay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      TextInput.finishAutofillContext();
      Navigator.pushReplacementNamed(context, '/main-shell');
    } else {
      _showError(authProvider.errorMessage);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.googleSignIn();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/main-shell');
    } else if (authProvider.errorMessage.isNotEmpty) {
      _showError(authProvider.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // FIXED: Using onSurface instead of deleted AppColors.textPrimaryLight/Dark
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(child: Image.asset('assets/images/app_logo.webp', height: 100)),
              const SizedBox(height: 30),

              Text(
                'Welcome Back!',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Log in to access your offline CBT exam simulator, detailed syllabus notes, and your personal AI Smart Tutor.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 30),

              AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CustomTextfield(
                        label: 'Email',
                        hintText: 'Enter your email address',
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        autofillHints: const [AutofillHints.email],
                        suffixIcon: Icons.email_outlined,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 15),

                      CustomTextfield(
                        label: 'Password',
                        hintText: 'Enter your password',
                        keyboardType: TextInputType.visiblePassword,
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.password],
                        enablePasswordToggle: true,
                        validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
                      ),
                      const SizedBox(height: 10),

                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/forget-password'),
                        style: TextButton.styleFrom(padding: const EdgeInsets.only(top: 8, bottom: 20)),
                        child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),

                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return CustomBtn(
                            label: auth.isLoading ? 'Logging in...' : 'Log In',
                            backgroundColor: AppColors.primary,
                            onPressed: auth.isLoading ? null : _handleLogin,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Google Sign-In Button
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                              icon: Image.asset('assets/images/google_logo.webp', height: 20, width: 20, errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 24)),
                              label: Text(
                                'Continue with Google',
                                style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.dividerColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // UPDATED: Sign Up Prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don\'t have an account? ',
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/signup');
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}