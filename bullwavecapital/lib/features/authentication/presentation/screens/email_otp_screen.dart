import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/otp_box.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

const _kResendSeconds = 60;

/// Second login factor, shown after phone OTP succeeds. Always starts on
/// email entry (pre-filled if the account already has one on file — see
/// [AuthProvider.existingEmailHint]) and only moves to OTP-code entry once
/// "Send OTP" actually dispatches a code. A local [_showOtpEntry] flag (not
/// provider state) drives which half shows, so "Change Email" can hop back
/// without any network call or losing the in-flight login.
class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final GlobalKey<ModernOtpInputState> _otpKey = GlobalKey<ModernOtpInputState>();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  int _secondsRemaining = _kResendSeconds;
  Timer? _timer;
  bool _isResending = false;
  bool _isVerifying = false;
  bool _isSendingOtp = false;
  bool _showOtpEntry = false;
  String _otp = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _emailController.text = auth.existingEmailHint ?? '';
    // If we're arriving with a code already sent (e.g. hot-reload while
    // mid-flow), skip straight to the OTP half instead of re-showing email
    // entry and forcing a needless resend.
    _showOtpEntry = auth.needsEmailVerification;
    if (_showOtpEntry) _startTimer();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = _kResendSeconds);
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

  Future<void> _sendOtp() async {
    if (_isSendingOtp) return;
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    setState(() => _isSendingOtp = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.submitLoginEmail(_emailController.text);
    if (!mounted) return;

    setState(() => _isSendingOtp = false);

    if (success) {
      setState(() {
        _showOtpEntry = true;
        _otp = '';
      });
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

  void _changeEmail() {
    _timer?.cancel();
    context.read<AuthProvider>().backToEmailEntry();
    setState(() {
      _showOtpEntry = false;
      _otp = '';
    });
    _otpKey.currentState?.clear();
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
          content: Text('Code sent to ${auth.pendingEmail ?? 'your email'}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not resend the code.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.red,
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

    final isBusy = _showOtpEntry
        ? (auth.isLoading || _isVerifying)
        : (auth.isLoading || _isSendingOtp);

    return PremiumAuthShell(
      matchAppTheme: true,
      glowPrimary: AppColors.brandPrimary,
      glowSecondary: AppColors.green,
      topBar: const PremiumBrandHeader(),
      bottomBar: PremiumAuthBottomBar(
        backEnabled: !isBusy,
        onBack: () => context.pop(),
        onNext: _showOtpEntry
            ? (_otp.replaceAll(RegExp(r'\D'), '').length == 6 && !isBusy ? _verifyOtp : () {})
            : (!isBusy ? _sendOtp : () {}),
        isLoading: isBusy,
        nextIcon: _showOtpEntry ? Icons.check_rounded : Icons.arrow_forward_rounded,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: _showOtpEntry
            ? _OtpEntryView(
                key: const ValueKey('otp-entry'),
                otpKey: _otpKey,
                colors: colors,
                pendingEmail: auth.pendingEmail,
                otp: _otp,
                isBusy: isBusy,
                canResend: _secondsRemaining == 0 && !_isResending,
                isResending: _isResending,
                secondsRemaining: _secondsRemaining,
                onOtpChanged: (value) => setState(() => _otp = value),
                onCompleted: (_) {
                  if (!_isVerifying && !auth.isLoading) _verifyOtp();
                },
                onResend: _resendOtp,
                onChangeEmail: isBusy ? null : _changeEmail,
              )
            : _EmailEntryView(
                key: const ValueKey('email-entry'),
                formKey: _emailFormKey,
                controller: _emailController,
                colors: colors,
                isBusy: isBusy,
                onSubmit: _sendOtp,
              ),
      ),
    );
  }
}

class _EmailEntryView extends StatelessWidget {
  const _EmailEntryView({
    super.key,
    required this.formKey,
    required this.controller,
    required this.colors,
    required this.isBusy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final AppThemeExtension colors;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          const Spacer(),
          PremiumAuthHero(
            pill: 'Second step',
            headline: 'VERIFY YOUR\nEMAIL',
            body: 'For extra security, every login needs a second code — enter your email and '
                "we'll send it there.",
            showLogo: false,
            belowBody: Column(
              children: [
                PremiumGlassField(
                  child: TextFormField(
                    controller: controller,
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
                    onFieldSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      hintStyle: GoogleFonts.inter(color: colors.textMuted, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Icon(Icons.mail_outline_rounded, color: AppColors.brandPrimary, size: 20),
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
    );
  }
}

class _OtpEntryView extends StatelessWidget {
  const _OtpEntryView({
    super.key,
    required this.otpKey,
    required this.colors,
    required this.pendingEmail,
    required this.otp,
    required this.isBusy,
    required this.canResend,
    required this.isResending,
    required this.secondsRemaining,
    required this.onOtpChanged,
    required this.onCompleted,
    required this.onResend,
    required this.onChangeEmail,
  });

  final GlobalKey<ModernOtpInputState> otpKey;
  final AppThemeExtension colors;
  final String? pendingEmail;
  final String otp;
  final bool isBusy;
  final bool canResend;
  final bool isResending;
  final int secondsRemaining;
  final ValueChanged<String> onOtpChanged;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final VoidCallback? onChangeEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        PremiumAuthHero(
          pill: 'Second step',
          headline: 'CHECK\nYOUR EMAIL',
          body: 'Code sent to',
          showLogo: false,
          belowBody: Column(
            children: [
              Text(
                pendingEmail ?? 'your email',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              PremiumGlassField(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: ModernOtpInput(
                    key: otpKey,
                    enabled: !isBusy,
                    onChanged: onOtpChanged,
                    onCompleted: onCompleted,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              canResend
                  ? TextButton(
                      onPressed: onResend,
                      child: Text(
                        isResending ? 'Sending...' : 'Resend Code',
                        style: GoogleFonts.inter(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Text(
                      'Resend in 0:${secondsRemaining.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onChangeEmail,
                child: Text(
                  'Change Email',
                  style: GoogleFonts.inter(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
    );
  }
}
