import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../profile/presentation/provider/app_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _phoneController = TextEditingController(text: auth.phoneNumber);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (!auth.termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept terms'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    auth.setPhoneNumber(_phoneController.text);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // TEMPORARY (testing, 2026-07-18) — skip OTP entirely and log straight
    // in with whatever number was entered. Set
    // DevConfig.skipOtpVerification back to false to restore the normal
    // send-OTP -> OTP screen flow.
    if (DevConfig.skipOtpVerification) {
      final loggedIn = await auth.devLoginSkipOtp();
      if (!mounted) return;
      if (loggedIn) {
        if (auth.needsProfileSetup) {
          router.go(AppRoutes.completeProfile);
        } else {
          unawaited(refreshAllProviders(context));
          router.go(AppRoutes.home);
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(auth.error ?? 'Failed to log in'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await auth.sendOtp();
    if (!mounted) return;

    if (success) {
      if (AppEnv.showDevOtpHints && auth.otpIsConsoleMode) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              auth.devOtp != null
                  ? 'Dev mode — OTP: ${auth.devOtp} (not sent via SMS)'
                  : 'Dev mode — check Django terminal for OTP (SMS not configured)',
            ),
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      router.push(AppRoutes.otp);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to send OTP'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canGoBackToOnboarding =
        !context.watch<AppProvider>().hasCompletedOnboarding;
    final colors = context.appColors;

    return PremiumAuthShell(
      matchAppTheme: true,
      glowPrimary: AppColors.brandPrimary,
      glowSecondary: AppColors.brandPink,
      topBar: PremiumBrandHeader(
        trailing: canGoBackToOnboarding
            ? TextButton(
                onPressed: () => context.go(AppRoutes.onboarding),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              )
            : null,
      ),
      bottomBar: PremiumAuthBottomBar(
        showBack: canGoBackToOnboarding,
        backEnabled: canGoBackToOnboarding,
        onBack: canGoBackToOnboarding
            ? () => context.go(AppRoutes.onboarding)
            : () {},
        onNext: _continue,
        isLoading: auth.isLoading,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Spacer(),
            PremiumAuthHero(
              pill: 'Sign in',
              headline: 'WELCOME\nBACK',
              body: 'Enter your mobile number. We\'ll send a secure 6-digit OTP to verify you.',
              showLogo: true,
              belowBody: PremiumGlassField(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (value == null || value.length != 10) {
                      return 'Enter a valid 10 digit number';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: GoogleFonts.inter(
                      color: colors.textMuted,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        '+91',
                        style: GoogleFonts.inter(
                          color: AppColors.brandCyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: auth.termsAccepted,
                      onChanged: (v) => auth.setTermsAccepted(v ?? false),
                      side: BorderSide(color: colors.textPrimary.withValues(alpha: 0.3)),
                      activeColor: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => auth.setTermsAccepted(!auth.termsAccepted),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colors.textSecondary,
                            height: 1.5,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                color: AppColors.brandCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.brandCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
