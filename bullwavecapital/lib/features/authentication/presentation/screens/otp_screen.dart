import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/otp_box.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<ModernOtpInputState> _otpKey = GlobalKey<ModernOtpInputState>();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isResending = false;
  bool _isVerifying = false;
  String _otp = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String _maskedPhone(String phone) {
    if (phone.length != 10) return phone;
    return '${phone.substring(0, 5)} ${phone.substring(5)}';
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    final auth = context.read<AuthProvider>();
    final code = _otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || auth.isLoading) return;

    if (auth.phoneNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number missing. Go back and enter your number again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.verifyOtp(code);
    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (success) {
      if (auth.needsProfileSetup) {
        router.go(AppRoutes.completeProfile);
      } else {
        unawaited(refreshAllProviders(context));
        router.go(AppRoutes.home);
      }
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(auth.error ?? 'Incorrect OTP. Please try again.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.red,
      ),
    );
    _otpKey.currentState?.clear();
    setState(() => _otp = '');
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isResending) return;

    final auth = context.read<AuthProvider>();
    if (auth.phoneNumber.length != 10) return;

    setState(() => _isResending = true);
    final sent = await auth.sendOtp();
    if (!mounted) return;

    setState(() => _isResending = false);

    if (sent) {
      _otpKey.currentState?.clear();
      setState(() => _otp = '');
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppEnv.showDevOtpHints && auth.otpIsConsoleMode
                ? (auth.devOtp != null
                    ? 'Dev mode — new OTP: ${auth.devOtp}'
                    : 'Dev mode — check Django terminal for OTP')
                : 'OTP sent to +91 ${auth.phoneNumber}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canResend = _secondsRemaining == 0 && !_isResending;
    final isBusy = auth.isLoading || _isVerifying;
    final canVerify = _otp.replaceAll(RegExp(r'\D'), '').length == 6 && !isBusy;
    final colors = context.appColors;

    return PremiumAuthShell(
      matchAppTheme: true,
      glowPrimary: AppColors.brandCyan,
      glowSecondary: AppColors.brandPrimary,
      topBar: const PremiumBrandHeader(),
      bottomBar: PremiumAuthBottomBar(
        backEnabled: !isBusy,
        onBack: () => context.pop(),
        onNext: canVerify ? _verifyOtp : () {},
        isLoading: isBusy,
        nextIcon: Icons.check_rounded,
      ),
      child: Column(
        children: [
          const Spacer(),
          PremiumAuthHero(
            pill: 'Verification',
            headline: 'ENTER\nOTP',
            body: AppEnv.showDevOtpHints && auth.otpIsConsoleMode
                ? 'Dev mode: SMS is not configured. Use the OTP shown below or in the Django terminal.'
                : 'We sent a 6-digit code to +91 ${_maskedPhone(auth.phoneNumber)}',
            showLogo: false,
            belowBody: Column(
              children: [
                if (AppEnv.showDevOtpHints && auth.otpIsConsoleMode)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brandCyan.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'SMS not configured — OTP is shown here for testing only.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (AppEnv.showDevOtpHints && auth.devOtp != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.positive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.positive.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'Dev OTP: ${auth.devOtp}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: colors.positive,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                PremiumGlassField(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: ModernOtpInput(
                      key: _otpKey,
                      enabled: !isBusy,
                      onChanged: (value) => setState(() => _otp = value),
                      onCompleted: (_) {
                        if (!_isVerifying && !auth.isLoading) _verifyOtp();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                canResend
                    ? TextButton(
                        onPressed: _resendOtp,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend OTP',
                          style: GoogleFonts.inter(
                            color: AppColors.brandCyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Text(
                        'Resend in 0:${_secondsRemaining.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
