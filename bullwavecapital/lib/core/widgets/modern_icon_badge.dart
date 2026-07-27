import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_a.dart';
import 'app_brand_logo.dart';

enum IconBadgeStyle { solid, glass, premiumCircle }

/// Centered gradient icon orb with gloss — explore / feature tiles.
class ModernIconBadge extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final List<Color> gradient;
  final Color iconColor;
  final double size;
  final IconBadgeStyle style;

  const ModernIconBadge({
    super.key,
    this.asset,
    this.icon,
    required this.gradient,
    this.iconColor = Colors.white,
    this.size = 52,
    this.style = IconBadgeStyle.glass,
  }) : assert(asset != null || icon != null);

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case IconBadgeStyle.solid:
        return _SolidIconBadge(
          asset: asset,
          icon: icon,
          gradient: gradient,
          iconColor: iconColor,
          size: size,
        );
      case IconBadgeStyle.premiumCircle:
        return _PremiumCircleIconBadge(
          asset: asset,
          icon: icon,
          gradient: gradient,
          size: size,
        );
      case IconBadgeStyle.glass:
        return _GlassIconBadge(
          asset: asset,
          icon: icon,
          gradient: gradient,
          iconColor: iconColor,
          size: size,
        );
    }
  }
}

class _SolidIconBadge extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final List<Color> gradient;
  final Color iconColor;
  final double size;

  const _SolidIconBadge({
    required this.asset,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final glyphSize = size * 0.46;
    final radius = size * 0.28;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.38),
              blurRadius: 12,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.08,
              left: size * 0.12,
              right: size * 0.12,
              child: Container(
                height: size * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.42),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            if (asset != null)
              AppSvgIcon(asset: asset!, size: glyphSize, color: iconColor)
            else
              Icon(icon, color: iconColor, size: glyphSize),
          ],
        ),
      ),
    );
  }
}

class _GlassIconBadge extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final List<Color> gradient;
  final Color iconColor;
  final double size;

  const _GlassIconBadge({
    required this.asset,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glyphSize = size * 0.44;
    final radius = size * 0.26;
    final accent = gradient.first;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 4),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
          ),
          // Glass tile
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.03),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0.72),
                          ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.42 : 0.28),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Inner gradient wash
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            radius: 1.1,
                            colors: [
                              accent.withValues(alpha: isDark ? 0.22 : 0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top gloss
                    Positioned(
                      top: size * 0.06,
                      left: size * 0.1,
                      right: size * 0.1,
                      child: Container(
                        height: size * 0.2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: isDark ? 0.18 : 0.55),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Icon with subtle gradient tint
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          gradient.length > 1 ? gradient.last : accent,
                        ],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: asset != null
                          ? AppSvgIcon(asset: asset!, size: glyphSize, color: Colors.white)
                          : Icon(icon, color: Colors.white, size: glyphSize),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCircleIconBadge extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final List<Color> gradient;
  final double size;

  const _PremiumCircleIconBadge({
    required this.asset,
    required this.icon,
    required this.gradient,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final glyphSize = size * 0.42;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: p.iconCircleDecoration().copyWith(
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Center(
          // Use `p.primary` (not `primaryDark`) for the glyph: in light
          // mode primary is the dark forest-green (reads fine on the pale
          // iconBg tint), and in dark mode primary is the bright emerald
          // (reads fine on the near-black iconBg) — primaryDark is a very
          // dark green in BOTH themes, which made icons nearly invisible
          // against the dark-mode icon circle background.
          child: asset != null
              ? AppSvgIcon(asset: asset!, size: glyphSize, color: p.primary)
              : Icon(icon, color: p.primary, size: glyphSize),
        ),
      ),
    );
  }
}

/// Gradient initial avatar for stock rows.
class ModernStockAvatar extends StatelessWidget {
  final String symbol;
  final double size;

  const ModernStockAvatar({
    super.key,
    required this.symbol,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final letter = symbol.isNotEmpty ? symbol.substring(0, 1).toUpperCase() : '?';
    final hue = symbol.hashCode.abs() % 360;
    final hue2 = (hue + 28) % 360;

    Color hsl(double h, double s, double l) =>
        HSLColor.fromAHSL(1, h, s, l).toColor();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hsl(hue.toDouble(), 0.55, 0.52),
            hsl(hue2.toDouble(), 0.62, 0.44),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: hsl(hue.toDouble(), 0.55, 0.44).withValues(alpha: 0.28),
            blurRadius: 8,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          height: 1,
        ),
      ),
    );
  }
}
