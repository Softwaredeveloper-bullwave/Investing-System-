import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color iconBg;
  final Color iconBorder;
  final Color positive;
  final Color negative;
  final Color onPrimary;
  final Color accentOrange;

  const AppThemeExtension({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.iconBg,
    required this.iconBorder,
    required this.positive,
    required this.negative,
    required this.onPrimary,
    required this.accentOrange,
  });

  static const light = AppThemeExtension(
    background: Color(0xFFF4F4F0),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFFAFAF8),
    border: Color(0xFFE8E8E3),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF5C5C58),
    textMuted: Color(0xFF8A8A85),
    shimmerBase: Color(0xFFE8E8E3),
    shimmerHighlight: Color(0xFFF4F4F0),
    primary: Color(0xFFC6FF00),
    primaryDark: Color(0xFF0A0A0A),
    primaryLight: Color(0xFFF0FFD6),
    iconBg: Color(0xFFF0FFD6),
    iconBorder: Color(0xFFDCF5A0),
    positive: Color(0xFF15803D),
    negative: Color(0xFFDC2626),
    onPrimary: Color(0xFF0A0A0A),
    accentOrange: Color(0xFFEA580C),
  );

  static const dark = AppThemeExtension(
    background: Color(0xFF0C0C0C),
    surface: Color(0xFF1C1C1C),
    surfaceSecondary: Color(0xFF161616),
    border: Color(0xFF2E2E2E),
    textPrimary: Color(0xFFF5F5F0),
    textSecondary: Color(0xFFD0D0CA),
    textMuted: Color(0xFFAEAEA8),
    shimmerBase: Color(0xFF1C1C1C),
    shimmerHighlight: Color(0xFF2E2E2E),
    primary: Color(0xFFC6FF00),
    primaryDark: Color(0xFFC6FF00),
    primaryLight: Color(0xFF1A2208),
    iconBg: Color(0xFF1A2208),
    iconBorder: Color(0xFF3D4F0A),
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFFF6B6B),
    onPrimary: Color(0xFF0A0A0A),
    accentOrange: Color(0xFFFB923C),
  );

  @override
  AppThemeExtension copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? iconBg,
    Color? iconBorder,
    Color? positive,
    Color? negative,
    Color? onPrimary,
    Color? accentOrange,
  }) {
    return AppThemeExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      iconBg: iconBg ?? this.iconBg,
      iconBorder: iconBorder ?? this.iconBorder,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      onPrimary: onPrimary ?? this.onPrimary,
      accentOrange: accentOrange ?? this.accentOrange,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      iconBg: Color.lerp(iconBg, other.iconBg, t)!,
      iconBorder: Color.lerp(iconBorder, other.iconBorder, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeExtension get appColors =>
      Theme.of(this).extension<AppThemeExtension>() ?? AppThemeExtension.light;
}

extension AppThemeState on ThemeData {
  AppThemeExtension get appColors =>
      extension<AppThemeExtension>() ?? AppThemeExtension.light;
}
