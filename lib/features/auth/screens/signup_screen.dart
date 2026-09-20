import 'package:utme_pass_at_once/core/utils/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/constants/app_colors.dart';
import 'package:utme_pass_at_once/core/utils/custom_btn.dart';
import 'package:utme_pass_at_once/core/utils/custom_textfield.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import 'package:utme_pass_at_once/routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:utme_pass_at_once/core/utils/bg.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Gesture Recognizers for clickable text
  late TapGestureRecognizer _privacyRecognizer;
  late TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.pushNamed(context, AppRoutes.privacyPolicy);
      };

    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.pushNamed(context, AppRoutes.termsOfService);
      };
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
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
      barrierDismissible: false,
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

  Future<void> _handleSignUp() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _fullNameController.text.trim(),
      _phoneController.text.trim(),
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
    final isDark = theme.brightness == Brightness.dark;

    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    const sizeBox = SizedBox(height: 14);

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
                  const SizedBox(height: 20),

                  Text(
                        'Create Account',
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
                        'Join thousands of students practicing with real CBT simulators and acing their exams at one sitting!',
                        style: GoogleFonts.plusJakartaSans(
                          color: secondaryTextColor.withValues(alpha: 0.8),
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 250.ms)
                      .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 28),

                  // Glassmorphic Card
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
                              children: [
                                CustomTextfield(
                                  label: 'Full Name',
                                  hintText: 'Enter your full name',
                                  keyboardType: TextInputType.name,
                                  controller: _fullNameController,
                                  autofillHints: const [AutofillHints.name],
                                  suffixIcon: Icons.person_outline_rounded,
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Full name is required'
                                      : null,
                                ),
                                sizeBox,

                                CustomTextfield(
                                  label: 'Email',
                                  hintText: 'Enter your email address',
                                  keyboardType: TextInputType.emailAddress,
                                  controller: _emailController,
                                  autofillHints: const [AutofillHints.email],
                                  suffixIcon: Icons.email_outlined,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty)
                                      return 'Email is required';
                                    if (!value.contains('@') ||
                                        !value.contains('.'))
                                      return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                sizeBox,

                                CustomTextfield(
                                  label: 'Phone Number',
                                  hintText: 'Enter your phone number',
                                  keyboardType: TextInputType.phone,
                                  controller: _phoneController,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber,
                                  ],
                                  suffixIcon: Icons.phone_outlined,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty)
                                      return 'Phone number is required';
                                    if (!RegExp(r'^\d{11}$').hasMatch(value))
                                      return 'Enter a valid 11-digit phone number';
                                    return null;
                                  },
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                ),
                                sizeBox,

                                CustomTextfield(
                                  label: 'Password',
                                  hintText: 'Create a password',
                                  obscureText: true,
                                  keyboardType: TextInputType.visiblePassword,
                                  controller: _passwordController,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  enablePasswordToggle: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty)
                                      return 'Password is required';
                                    if (value.length < 6)
                                      return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),
                                sizeBox,

                                CustomTextfield(
                                  label: 'Confirm Password',
                                  hintText: 'Re-enter your password',
                                  obscureText: true,
                                  keyboardType: TextInputType.visiblePassword,
                                  controller: _confirmPasswordController,
                                  autofillHints: const [AutofillHints.password],
                                  enablePasswordToggle: true,
                                  validator: (value) =>
                                      (value != _passwordController.text)
                                      ? 'Passwords do not match'
                                      : null,
                                ),
                                const SizedBox(height: 24),

                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: secondaryTextColor.withValues(
                                        alpha: 0.7,
                                      ),
                                      height: 1.45,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text:
                                            'By creating an account, you agree to our ',
                                      ),
                                      TextSpan(
                                        text: 'Privacy Policies',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: _privacyRecognizer,
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Terms of Service.',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: _termsRecognizer,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                Consumer<AuthProvider>(
                                  builder: (context, auth, _) {
                                    return CustomBtn(
                                      label: auth.isLoading
                                          ? 'Creating Account...'
                                          : 'Create an Account',
                                      backgroundColor: AppColors.primary,
                                      onPressed: auth.isLoading
                                          ? null
                                          : _handleSignUp,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),

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
                                          color: secondaryTextColor.withValues(
                                            alpha: 0.6,
                                          ),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          'Login',
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
