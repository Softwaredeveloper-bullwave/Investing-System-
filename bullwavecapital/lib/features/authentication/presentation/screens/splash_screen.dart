import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/constants/routes.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../../profile/presentation/provider/app_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/splash_animation.dart';

/// Entry screen — always shown first, then routes to onboarding or auth.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      auth.tryRestoreSession(),
    ]);
    if (!mounted) return;

    // First launch: splash → onboarding → login → OTP → app.
    if (!app.hasCompletedOnboarding) {
      if (auth.isAuthenticated) {
        await auth.logout();
      }
      if (!mounted) return;
      context.go(AppRoutes.onboarding);
      return;
    }

    // Returning user with valid session → home.
    if (auth.isAuthenticated) {
      final kyc = context.read<KycFlowProvider>();
      await kyc.loadStatus();
      if (!mounted) return;

      if (auth.needsProfileSetup) {
        context.go(AppRoutes.completeProfile);
      } else {
        unawaited(refreshAllProviders(context));
        context.go(AppRoutes.home);
      }
      return;
    }

    // Onboarding done but logged out → login → OTP.
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const SplashAnimation();
  }
}
