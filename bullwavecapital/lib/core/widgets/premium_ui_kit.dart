import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';
import '../theme/theme_a.dart';
import 'scale_tap.dart';

/// Frosted glass card with subtle border, gradient wash, and soft shadow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final bool glow;
  final Color? glowColor;
  final Gradient? gradientOverlay;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = 22,
    this.glow = false,
    this.glowColor,
    this.gradientOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: p.cardDecoration(radius: radius),
      child: child,
    );

    if (onTap == null) return content;
    return ScaleTap(onTap: onTap, child: content);
  }
}

/// Circular glass icon button with neon glow.
class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final double size;
  final int? badge;

  const NeonIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.accent = AppColors.brandPrimary,
    this.size = 44,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ScaleTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(icon, color: colors.textPrimary, size: size * 0.48),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.warningRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Big rounded glass search bar.
class PremiumSearchBar extends StatelessWidget {
  final VoidCallback? onTap;
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const PremiumSearchBar({
    super.key,
    this.onTap,
    this.hint = 'Search stocks & markets',
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final interactive = controller != null || onChanged != null;

    final decoration = p.cardDecoration(radius: 999);

    if (interactive) {
      return Container(
        decoration: decoration,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            color: p.textDark,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: p.textGrey, fontSize: 15),
            prefixIcon: Icon(Icons.search_rounded, color: p.textGrey, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          ),
        ),
      );
    }

    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: decoration,
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 22, color: p.textGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: p.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped gradient CTA button.
class GradientActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined;
  final Gradient? gradient;

  const GradientActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.outlined = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (outlined) {
      return ScaleTap(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: p.isDark ? p.primary.withValues(alpha: 0.45) : p.borderLight,
            ),
            color: p.isDark ? p.surface : p.card,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: p.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ScaleTap(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: p.isDark ? p.primary : p.heroCard,
          boxShadow: [
            BoxShadow(
              color: (p.isDark ? p.primary : p.heroCard).withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: p.isDark ? p.onPrimary : p.heroCardFg, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: p.isDark ? p.onPrimary : p.heroCardFg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PremiumAlertType { warning, error, info, success }

/// Premium inline alert banner (replaces plain error text).
class PremiumAlertBanner extends StatelessWidget {
  final String message;
  final PremiumAlertType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PremiumAlertBanner({
    super.key,
    required this.message,
    this.type = PremiumAlertType.warning,
    this.actionLabel,
    this.onAction,
  });

  Color get _accent {
    switch (type) {
      case PremiumAlertType.error:
        return AppColors.warningRed;
      case PremiumAlertType.success:
        return AppColors.green;
      case PremiumAlertType.info:
        return AppColors.brandCyan;
      case PremiumAlertType.warning:
        return AppColors.warningAmber;
    }
  }

  IconData get _icon {
    switch (type) {
      case PremiumAlertType.error:
        return Icons.error_outline_rounded;
      case PremiumAlertType.success:
        return Icons.check_circle_outline_rounded;
      case PremiumAlertType.info:
        return Icons.info_outline_rounded;
      case PremiumAlertType.warning:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      glowColor: _accent,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Icon(_icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.inter(
                  color: _accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// AI Market Insights premium gradient card.
class AiInsightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AiInsightCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppColors.aiInsightGradient,
          border: Border.all(color: AppColors.brandPrimaryLight.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandCyan.withValues(alpha: 0.35),
                    AppColors.brandPrimary.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandCyan.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini trading card for market indices.
class MarketCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;

  const MarketCard({
    super.key,
    required this.label,
    required this.value,
    required this.change,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final changeColor = isPositive ? AppColors.green : AppColors.warningRed;

    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            change,
            style: GoogleFonts.inter(
              color: changeColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portfolio value hero card with gradient glass.
class PortfolioCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PortfolioCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      glow: true,
      onTap: onTap,
      child: child,
    );
  }
}

/// Profile menu row with neon icon orb.
class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? accent;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final iconAccent = accent ?? p.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: p.iconCircleDecoration(),
              child: Icon(icon, color: iconAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.typeCardTitle(15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.typeSecondary(13)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
