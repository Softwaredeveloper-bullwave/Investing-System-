import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Second login factor, shown after phone OTP succeeds. Two states, on the
/// same screen/route so the transition between them feels like one flow:
///
/// 1. [AuthProvider.needsEmailSetup] — account has no email on file yet, so
///    this collects one and calls [AuthProvider.submitLoginEmail], which
///    saves it and sends the first code.
/// 2. [AuthProvider.needsEmailVerification] — a code was sent (either just
///    now, or because the account already had an email) — enter it here to
///    complete login via [AuthProvider.verifyEmailOtp].
class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final GlobalKey<ModernOtpInputState> _otpKey = GlobalKey<ModernOtpInputState>();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isResending = false;
  bool _isVerifying = false;
  bool _isSubmittingEmail = false;
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

  Future<void> _submitEmail() async {
    if (_isSubmittingEmail) return;
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    setState(() => _isSubmittingEmail = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.submitLoginEmail(_emailController.text);
    if (!mounted) return;

    setState(() => _isSubmittingEmail = false);

    if (success) {
      _startTimer();
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(auth.error ?? 'Could not send the code. Please try again.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.red,
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    final auth = context.read<AuthProvider>();
    final code = _otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || auth.isLoading) return;

    setState(() => _isVerifying = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.verifyEmailOtp(code);
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
        content: Text(auth.error ?? 'Incorrect code. Please try again.'),
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
    setState(() => _isResending = true);
    final sent = await auth.resendEmailOtp();
    if (!mounted) return;

    setState(() => _isResending = false);

    if (sent) {
      _otpKey.currentState?.clear();
      setState(() => _otp = '');
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppEnv.showDevOtpHints && auth.emailOtpIsConsoleMode
                ? (auth.devEmailOtp != null
                    ? 'Dev mode — new code: ${auth.devEmailOtp}'
                    : 'Dev mode — check Django terminal for the code')
                : 'Code sent to ${auth.pendingEmailMasked ?? 'your email'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = context.appColors;

    if (auth.needsEmailSetup) {
      return _buildEmailEntry(context, auth, colors);
    }
    return _buildOtpEntry(context, auth, colors);
  }

  Widget _buildEmailEntry(BuildContext context, AuthProvider auth, AppThemeExtension colors) {
    final isBusy = auth.isLoading || _isSubmittingEmail;

    return PremiumAuthShell(
      matchAppTheme: true,
      glowPrimary: AppColors.brandCyan,
      glowSecondary: AppColors.brandPrimary,
      topBar: const PremiumBrandHeader(),
      bottomBar: PremiumAuthBottomBar(
        backEnabled: !isBusy,
        onBack: () => context.pop(),
        onNext: isBusy ? () {} : _submitEmail,
        isLoading: isBusy,
        nextIcon: Icons.arrow_forward_rounded,
      ),
      child: Form(
        key: _emailFormKey,
        child: Column(
          children: [
            const Spacer(),
            PremiumAuthHero(
              pill: 'Second step',
              headline: 'ADD YOUR\nEMAIL',
              body: 'For extra security, every login needs a second code — enter an email and '
                  "we'll send it there.",
              showLogo: false,
              belowBody: Column(
                children: [
                  PremiumGlassField(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      enabled: !isBusy,
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty || !v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submitEmail(),
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        hintStyle: GoogleFonts.inter(color: colors.textMuted, fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          child: Icon(Icons.mail_outline_rounded, color: AppColors.brandCyan, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: colors.textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "We'll only use this to send login codes and important account alerts.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: colors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildOtpEntry(BuildContext context, AuthProvider auth, AppThemeExtension colors) {
    final canResend = _secondsRemaining == 0 && !_isResending;
    final isBusy = auth.isLoading || _isVerifying;
    final canVerify = _otp.replaceAll(RegExp(r'\D'), '').length == 6 && !isBusy;

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
            pill: 'Second step',
            headline: 'CHECK\nYOUR EMAIL',
            body: AppEnv.showDevOtpHints && auth.emailOtpIsConsoleMode
                ? 'Dev mode: email sending is not configured. Use the code shown below or in the Django terminal.'
                : 'We sent a 6-digit code to ${auth.pendingEmailMasked ?? 'your email'} — this extra step keeps your account secure even if someone gets your phone.',
            showLogo: false,
            belowBody: Column(
              children: [
                if (AppEnv.showDevOtpHints && auth.emailOtpIsConsoleMode)
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
                      'Email sending not configured — code is shown here for testing only.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (AppEnv.showDevOtpHints && auth.devEmailOtp != null)
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
                      'Dev code: ${auth.devEmailOtp}',
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
                          _isResending ? 'Sending...' : 'Resend Code',
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
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 15, color: colors.textMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Don't share this code with anyone, including Capital Bullwave support.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
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
