import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import '../models/device_lock_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';
import 'package:utme_pass_at_once/core/utils/custom_textfield.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:google_fonts/google_fonts.dart';

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.red,
                  size: 28,
                ),
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
                message.replaceAll(
                  'Your account has been suspended by the admin.\n',
                  '',
                ),
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
      return;
    }

    // Refused because the account belongs to another phone: offer the move
    // rather than leaving them at an error they cannot act on.
    final lock = authProvider.pendingDeviceLock;
    if (lock != null) {
      await _handleDeviceLock(lock);
      return;
    }

    _showError(authProvider.errorMessage);
  }

  /// Ask whether to move the account onto this phone.
  Future<void> _handleDeviceLock(DeviceLockException lock) async {
    final authProvider = context.read<AuthProvider>();
    final theme = Theme.of(context);
    final bound = lock.boundDeviceName;

    final move = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          lock.canMove ? Icons.phonelink_setup_rounded : Icons.lock_rounded,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          lock.canMove ? 'Move to this phone?' : 'Locked to another phone',
        ),
        content: Text(
          lock.canMove
              ? 'Your account is currently on '
                    '${bound ?? 'another phone'}. Moving it here will sign that '
                    'phone out, and you can download your exams again on this '
                    'one. '
                    'You can do this ${lock.movesLeft} more '
                    '${lock.movesLeft == 1 ? 'time' : 'times'}.'
              : 'Your account is on ${bound ?? 'another phone'} and you have '
                    'used all your device changes. Please contact support and '
                    'we will move it for you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          if (lock.canMove)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Move it here'),
            ),
        ],
      ),
    );

    if (!mounted) return;

    if (move != true) {
      await authProvider.cancelDeviceMove();
      return;
    }

    final moved = await authProvider.moveAccountToThisDevice();
    if (!mounted) return;
    if (moved) {
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
      return;
    }

    final lock = authProvider.pendingDeviceLock;
    if (lock != null) {
      await _handleDeviceLock(lock);
      return;
    }

    if (authProvider.errorMessage.isNotEmpty) {
      _showError(authProvider.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          const BlobBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // App Logo with scale and fade animation
                  Center(
                        child: Image.asset(
                          'assets/images/app_logo.webp',
                          height: 90,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 24),

                  // Welcome Title & Subtitle with slide animation
                  Text(
                        'Welcome Back!',
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 150.ms)
                      .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 8),
                  Text(
                        'Log in to access your offline CBT exam simulator, detailed syllabus notes, and your personal AI Smart Tutor.',
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 250.ms)
                      .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 28),

                  // Glassmorphic Login Card
                  Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E).withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.25 : 0.04,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: AutofillGroup(
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
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Email is required'
                                      : null,
                                ),
                                const SizedBox(height: 20),

                                CustomTextfield(
                                  label: 'Password',
                                  hintText: 'Enter your password',
                                  keyboardType: TextInputType.visiblePassword,
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  enablePasswordToggle: true,
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                      ? 'Password is required'
                                      : null,
                                ),
                                const SizedBox(height: 8),

                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/forget-password',
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 24,
                                    ),
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),

                                Consumer<AuthProvider>(
                                  builder: (context, auth, _) {
                                    return CustomBtn(
                                      label: auth.isLoading
                                          ? 'Logging in...'
                                          : 'Log In',
                                      backgroundColor: AppColors.primary,
                                      onPressed: auth.isLoading
                                          ? null
                                          : _handleLogin,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Divider text OR
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Google Sign-In Button
                                Consumer<AuthProvider>(
                                  builder: (context, auth, _) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: OutlinedButton.icon(
                                        onPressed: auth.isLoading
                                            ? null
                                            : _handleGoogleSignIn,
                                        icon: Image.asset(
                                          'assets/images/google_logo.webp',
                                          height: 20,
                                          width: 20,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.g_mobiledata,
                                            size: 24,
                                          ),
                                        ),
                                        label: Text(
                                          'Continue with Google',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.12,
                                                  )
                                                : theme.dividerColor,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          backgroundColor: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.02,
                                                )
                                              : Colors.transparent,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 350.ms)
                      .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 32),

                  // Sign Up Prompt
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/signup');
                        },
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
