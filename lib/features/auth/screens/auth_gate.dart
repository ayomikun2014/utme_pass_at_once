import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utme_pass_at_once/core/screens/splash_screen.dart';
import 'package:utme_pass_at_once/features/auth/providers/auth_provider.dart';
import 'package:utme_pass_at_once/routes.dart';
import '../../../main.dart';
import '../../../core/services/notification_service.dart';

/// A gate screen that shows the [SplashScreen] animation while concurrently
/// checking for an existing user session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;
  bool _isAuthChecked = false;
  bool _isAnimationComplete = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// Perform the initial authentication check.
  Future<void> _checkAuth() async {
    final authProvider = context.read<AuthProvider>();

    // Attempt auto-login (checks Hive cache + Firebase validity)
    _isLoggedIn = await authProvider.tryAutoLogin();

    _isAuthChecked = true;
    _maybeNavigate();
  }

  /// Called when the [SplashScreen] has finished its intro animation.
  void _onAnimationComplete() {
    setState(() {
      _isAnimationComplete = true;
    });
    _maybeNavigate();
  }

  /// Navigates only if BOTH the animation is complete and the auth check is finished.
  void _maybeNavigate() {
    if (_isAuthChecked && _isAnimationComplete) {
      if (!mounted) return;

      if (_isLoggedIn) {
        // User is logged in, send to the main app interface
        Navigator.pushReplacementNamed(context, AppRoutes.mainShell);

        // Handle pending deep link or notification (Cold Start Routing Queue)
        if (NotificationService.pendingRoute != null) {
          final pendingRouteData = NotificationService.pendingRoute!;
          NotificationService.pendingRoute = null; // Clear it immediately

          WidgetsBinding.instance.addPostFrameCallback((_) {
            rootNavigatorKey.currentState?.pushNamed(
              pendingRouteData['route'],
              arguments: pendingRouteData,
            );
          });
        }
      } else {
        // No valid session, send to onboarding
        Navigator.pushReplacementNamed(context, AppRoutes.onBoarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show the splash screen while the gate is processing
    return SplashScreen(onComplete: _onAnimationComplete);
  }
}
