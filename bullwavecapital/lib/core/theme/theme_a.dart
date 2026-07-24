import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/shell_layout.dart';

/// BullWave Pro — ink + electric lime + warm stone surfaces.
@immutable
class ThemePalette {
  final Color bg;
  final Color surface;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color primaryBorder;
  final Color walletAccent;
  final Color iconBg;
  final Color iconBorder;
  final Color textDark;
  final Color textGrey;
  final Color textMuted;
  final Color card;
  final Color borderLight;
  final Color positive;
  final Color negative;
  final Color accentOrange;
  final double cardRadius;
  final Color onPrimary;
  final Color heroCard;
  final Color heroCardEnd;
  final Color heroCardFg;
  final Color heroCardMuted;
  final Color accentSurface;
  final Color accentSurfaceEnd;
  final Color accentSurfaceFg;

  const ThemePalette({
    required this.bg,
    required this.surface,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryBorder,
    required this.walletAccent,
    required this.iconBg,
    required this.iconBorder,
    required this.textDark,
    required this.textGrey,
    required this.textMuted,
    required this.card,
    required this.borderLight,
    required this.positive,
    required this.negative,
    required this.accentOrange,
    this.cardRadius = 28,
    required this.onPrimary,
    required this.heroCard,
    required this.heroCardEnd,
    required this.heroCardFg,
    required this.heroCardMuted,
    required this.accentSurface,
    required this.accentSurfaceEnd,
    required this.accentSurfaceFg,
  });

  /// Light — Forest Green premium fintech: off-white canvas, deep forest
  /// green hero, emerald action accent, mint highlight.
  static const light = ThemePalette(
    bg: Color(0xFFF8FAF8),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF083007),
    primaryDark: Color(0xFF041C04),
    primarySoft: Color(0xFFE3F5E8),
    primaryBorder: Color(0xFFBFE5CA),
    walletAccent: Color(0xFF16A34A),
    iconBg: Color(0xFFE3F5E8),
    iconBorder: Color(0xFFBFE5CA),
    textDark: Color(0xFF1E293B),
    textGrey: Color(0xFF64748B),
    textMuted: Color(0xFF94A3AA),
    card: Color(0xFFFFFFFF),
    borderLight: Color(0xFFDDE8DD),
    positive: Color(0xFF16A34A),
    negative: Color(0xFFDC2626),
    accentOrange: Color(0xFFEA580C),
    onPrimary: Color(0xFFFFFFFF),
    heroCard: Color(0xFF083007),
    heroCardEnd: Color(0xFF041C04),
    heroCardFg: Color(0xFFFFFFFF),
    heroCardMuted: Color(0xCCFFFFFF),
    accentSurface: Color(0xFF16A34A),
    accentSurfaceEnd: Color(0xFF6EE7B7),
    accentSurfaceFg: Color(0xFFFFFFFF),
  );

  /// Dark — ink canvas, elevated graphite cards, emerald glow (Forest Green).
  static const dark = ThemePalette(
    bg: Color(0xFF0C0C0C),
    surface: Color(0xFF161616),
    primary: Color(0xFF16A34A),
    primaryDark: Color(0xFF083007),
    primarySoft: Color(0xFF102B16),
    primaryBorder: Color(0xFF1F4A2B),
    walletAccent: Color(0xFF16A34A),
    iconBg: Color(0xFF102B16),
    iconBorder: Color(0xFF1F4A2B),
    textDark: Color(0xFFF5F5F0),
    textGrey: Color(0xFFD0D0CA),
    textMuted: Color(0xFFAEAEA8),
    card: Color(0xFF1C1C1C),
    borderLight: Color(0xFF2E2E2E),
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFFF6B6B),
    accentOrange: Color(0xFFFB923C),
    onPrimary: Color(0xFFFFFFFF),
    heroCard: Color(0xFF083007),
    heroCardEnd: Color(0xFF041C04),
    heroCardFg: Color(0xFFFFFFFF),
    heroCardMuted: Color(0xCCFFFFFF),
    accentSurface: Color(0xFF16A34A),
    accentSurfaceEnd: Color(0xFF6EE7B7),
    accentSurfaceFg: Color(0xFFFFFFFF),
  );

  bool get isDark => identical(this, dark);

  /// Alias for legacy call sites.
  Color get primaryLight => primarySoft;

  BoxDecoration cardDecoration({Color? shadowTint, double? radius}) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(radius ?? cardRadius),
      border: Border.all(color: borderLight, width: 1),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: const Color(0xFF0A0A0A).withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: (shadowTint ?? primary).withValues(alpha: 0.04),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
    );
  }

  BoxDecoration heroCardDecoration({double? radius}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius ?? cardRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heroCard, heroCardEnd],
      ),
      border: Border.all(color: primary.withValues(alpha: isDark ? 0.22 : 0.12)),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ]
          : [
              BoxShadow(
                color: heroCard.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
    );
  }

  BoxDecoration accentCardDecoration({double? radius}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius ?? cardRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentSurface, accentSurfaceEnd],
      ),
      border: Border.all(color: accentSurfaceFg.withValues(alpha: 0.08)),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: accentSurface.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ]
          : [
              BoxShadow(
                color: accentSurface.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
    );
  }

  BoxDecoration iconCircleDecoration({Color? borderColor, Color? backgroundColor}) {
    return BoxDecoration(
      color: backgroundColor ?? iconBg,
      shape: BoxShape.circle,
      border: Border.all(color: borderColor ?? iconBorder, width: 1),
    );
  }

  BoxDecoration primaryPillDecoration({double? radius}) {
    return BoxDecoration(
      color: primarySoft,
      borderRadius: BorderRadius.circular(radius ?? 999),
      border: Border.all(color: primaryBorder),
    );
  }
}

extension ThemePaletteContext on BuildContext {
  ThemePalette get palette =>
      Theme.of(this).brightness == Brightness.dark ? ThemePalette.dark : ThemePalette.light;
}

class ThemeA {
  ThemeA._();

  static ThemePalette of(BuildContext context) => context.palette;

  static const bg = Color(0xFFF8FAF8);
  static const primary = Color(0xFF083007);
  static const primaryDark = Color(0xFF041C04);
  static const primarySoft = Color(0xFFE3F5E8);
  static const primaryLight = Color(0xFFE3F5E8);
  static const walletAccent = Color(0xFF16A34A);
  static const iconBg = Color(0xFFE3F5E8);
  static const iconBorder = Color(0xFFBFE5CA);
  static const textDark = Color(0xFF1E293B);
  static const textGrey = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3AA);
  static const card = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFDDE8DD);
  static const positive = Color(0xFF16A34A);
  static const negative = Color(0xFFDC2626);
  static const accentOrange = Color(0xFFEA580C);
  static const cardRadius = 28.0;
  static const onPrimary = Color(0xFFFFFFFF);

  static BoxDecoration cardDecoration({Color? shadowTint, double radius = cardRadius}) =>
      ThemePalette.light.cardDecoration(shadowTint: shadowTint, radius: radius);

  static BoxDecoration iconCircleDecoration({Color? borderColor, Color? backgroundColor}) =>
      ThemePalette.light.iconCircleDecoration(borderColor: borderColor, backgroundColor: backgroundColor);
}

class ThemeAType {
  ThemeAType._();

  static TextStyle heading({double size = 28, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? ThemeA.textDark,
        letterSpacing: -0.35,
        height: 1.1,
      );

  static TextStyle sectionTitle({double size = 18, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? ThemeA.textDark,
        letterSpacing: -0.25,
        height: 1.2,
      );

  static TextStyle cardTitle({double size = 15, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? ThemeA.textDark,
        letterSpacing: -0.12,
        height: 1.25,
      );

  static TextStyle body({double size = 15, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? ThemeA.textDark,
        height: 1.35,
      );

  static TextStyle secondary({double size = 14, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? ThemeA.textGrey,
        height: 1.35,
      );

  static TextStyle muted({double size = 13, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? ThemeA.textMuted,
        height: 1.35,
      );

  static TextStyle price({double size = 16, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? ThemeA.textDark,
        letterSpacing: -0.45,
        height: 1.05,
      );

  static TextStyle label({double size = 12, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? ThemeA.textDark,
        letterSpacing: -0.05,
        height: 1.2,
      );

  static TextStyle action({double size = 14, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? ThemeA.textDark,
        height: 1.2,
      );
}

extension NeoType on BuildContext {
  ThemePalette get p => palette;

  TextStyle get typeHeading => ThemeAType.heading(color: p.textDark);
  TextStyle typeSection([double size = 18]) => ThemeAType.sectionTitle(size: size, color: p.textDark);
  TextStyle typeCardTitle([double size = 15]) => ThemeAType.cardTitle(size: size, color: p.textDark);
  TextStyle typeBody([double size = 15]) => ThemeAType.body(size: size, color: p.textDark);
  TextStyle typeSecondary([double size = 14]) => ThemeAType.secondary(size: size, color: p.textGrey);
  TextStyle typeMuted([double size = 13]) => ThemeAType.muted(size: size, color: p.textMuted);
  TextStyle typePrice([double size = 16]) => ThemeAType.price(size: size, color: p.textDark);
  TextStyle typeLabel([double size = 13, Color? color]) =>
      ThemeAType.label(size: size, color: color ?? p.textDark);
  TextStyle typeAction([double size = 14]) => ThemeAType.action(size: size, color: p.primary);
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool reserveFabSpace;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.reserveFabSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        right: reserveFabSpace && actionLabel != null ? ShellLayout.fabActionClearance : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: ThemeAType.sectionTitle(color: p.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: p.primaryPillDecoration(),
                child: Text(
                  actionLabel!,
                  style: ThemeAType.label(size: 13, color: p.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
