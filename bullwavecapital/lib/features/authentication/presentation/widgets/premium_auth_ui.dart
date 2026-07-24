import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/app_brand_logo.dart';

/// Onboarding-style premium shell for splash, login, OTP, and profile setup.
///
/// By default renders the dark mesh look regardless of app theme mode (used
/// by login/OTP/profile-setup, unchanged). Pass [matchAppTheme]: true to
/// instead follow the app's actual light/dark setting — pale-lime mesh in
/// light mode, black mesh in dark mode — as splash & onboarding now do.
class PremiumAuthShell extends StatelessWidget {
  final Widget child;
  final Color glowPrimary;
  final Color glowSecondary;
  final Widget? topBar;
  final Widget? bottomBar;
  final bool matchAppTheme;

  const PremiumAuthShell({
    super.key,
    required this.child,
    this.glowPrimary = AppColors.brandPrimary,
    this.glowSecondary = AppColors.brandPink,
    this.topBar,
    this.bottomBar,
    this.matchAppTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = matchAppTheme ? Theme.of(context).brightness == Brightness.dark : true;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: GoogleFonts.interTextTheme(base.textTheme),
        extensions: [isDark ? AppThemeExtension.dark : AppThemeExtension.light],
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PremiumMeshBackground(
              glowPrimary: glowPrimary,
              glowSecondary: glowSecondary,
            ),
            const PremiumFilmGrain(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?topBar,
                  Expanded(child: child),
                  ?bottomBar,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumBrandHeader extends StatelessWidget {
  final Widget? trailing;

  const PremiumBrandHeader({super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final ink = context.appColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
      child: Row(
        children: [
          const AppBrandLogo(size: 32, showShadow: false, rounded: true),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Capital Bullwave',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class PremiumPillTag extends StatelessWidget {
  final String label;

  const PremiumPillTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final ink = context.appColors.textPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ink.withValues(alpha: 0.12)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: ink.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumAuthHeadline extends StatelessWidget {
  final String text;

  const PremiumAuthHeadline({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: context.appColors.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 34,
        height: 1.08,
        letterSpacing: -0.5,
      ),
    );
  }
}

class PremiumAuthBody extends StatelessWidget {
  final String text;

  const PremiumAuthBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: context.appColors.textSecondary,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 1.65,
        letterSpacing: 0.1,
      ),
    );
  }
}

class PremiumGlassField extends StatelessWidget {
  final Widget child;

  const PremiumGlassField({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ink = context.appColors.textPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ink.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PremiumLineIndicator extends StatelessWidget {
  final int count;
  final int current;

  const PremiumLineIndicator({super.key, required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final ink = context.appColors.textPrimary;
    final accent = context.appColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 32 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? accent : ink.withValues(alpha: 0.18),
            boxShadow: active
                ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

class PremiumThinProgress extends StatelessWidget {
  final double value;
  final String? label;

  const PremiumThinProgress({super.key, required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: GoogleFonts.inter(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: colors.textPrimary.withValues(alpha: 0.1),
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

class PremiumAuthBottomBar extends StatelessWidget {
  final bool showBack;
  final bool backEnabled;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool isLast;
  final String startLabel;
  final VoidCallback? onStart;
  final bool isLoading;
  final IconData nextIcon;

  const PremiumAuthBottomBar({
    super.key,
    this.showBack = true,
    this.backEnabled = true,
    this.onBack,
    required this.onNext,
    this.isLast = false,
    this.startLabel = 'Start',
    this.onStart,
    this.isLoading = false,
    this.nextIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    if (showBack)
                      PremiumCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        enabled: backEnabled,
                        onPressed: onBack,
                        filled: false,
                      )
                    else
                      const SizedBox(width: 46),
                    const Spacer(),
                    GestureDetector(
                      onTap: isLast ? onStart : null,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isLast ? 1.0 : 0.35,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              startLabel,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 2),
                            ...List.generate(3, (i) {
                              return Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withValues(alpha: 0.5 - i * 0.15),
                                size: 18,
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              child: Center(
                child: PremiumCircleIconButton(
                  icon: isLoading ? null : (isLast ? Icons.check_rounded : nextIcon),
                  onPressed: isLoading ? null : onNext,
                  filled: true,
                  isLoading: isLoading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumCircleIconButton extends StatefulWidget {
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool enabled;
  final bool isLoading;

  const PremiumCircleIconButton({
    super.key,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  State<PremiumCircleIconButton> createState() => _PremiumCircleIconButtonState();
}

class _PremiumCircleIconButtonState extends State<PremiumCircleIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled && widget.onPressed != null && !widget.isLoading;
    final size = widget.filled ? 68.0 : 46.0;
    // The filled CTA always uses the lime brand fill + near-black icon —
    // these two AppThemeExtension tokens are identical in light & dark mode,
    // so the button reads as "on brand" regardless of theme. The outline
    // "back" button lives inside the always-dark bottom pill, so it stays dark.
    final onPrimary = context.appColors.onPrimary;
    final primary = context.appColors.primary;

    return GestureDetector(
      onTapDown: canTap ? (_) => _press.forward() : null,
      onTapUp: canTap
          ? (_) {
              _press.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.enabled ? 1 : 0.25,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.filled ? primary : const Color(0xFF1E1E1E),
              border: widget.filled
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: widget.filled
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: AppColors.brandPink.withValues(alpha: 0.12),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: onPrimary),
                  )
                : Icon(
                    widget.icon,
                    color: widget.filled ? onPrimary : Colors.white.withValues(alpha: 0.85),
                    size: widget.filled ? 28 : 20,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Centered hero block used on splash + login.
class PremiumAuthHero extends StatelessWidget {
  final String pill;
  final String headline;
  final String body;
  final Widget? belowBody;
  final double logoSize;
  final bool showLogo;

  const PremiumAuthHero({
    super.key,
    required this.pill,
    required this.headline,
    required this.body,
    this.belowBody,
    this.logoSize = 88,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showLogo) ...[
            Hero(
              tag: 'logo',
              child: AppBrandLogo(size: logoSize, showShadow: true),
            ),
            const SizedBox(height: 28),
          ],
          PremiumPillTag(label: pill),
          const SizedBox(height: 28),
          PremiumAuthHeadline(text: headline),
          const SizedBox(height: 24),
          PremiumAuthBody(text: body),
          if (belowBody != null) ...[const SizedBox(height: 28), belowBody!],
        ],
      ),
    );
  }
}
