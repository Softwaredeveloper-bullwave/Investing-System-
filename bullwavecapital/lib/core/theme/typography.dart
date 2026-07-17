import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme_extension.dart';
import 'colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _style({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.35,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme forBrightness(AppThemeExtension colors) {
    TextStyle s({
      required double size,
      required FontWeight weight,
      Color? color,
      double? height,
      double? letterSpacing,
    }) {
      return _style(
        size: size,
        weight: weight,
        color: color ?? colors.textPrimary,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: s(size: 34, weight: FontWeight.w800, letterSpacing: -0.8),
      displayMedium: s(size: 30, weight: FontWeight.w800, letterSpacing: -0.6),
      displaySmall: s(size: 26, weight: FontWeight.w700, letterSpacing: -0.4),
      headlineLarge: s(size: 24, weight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: s(size: 20, weight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: s(size: 18, weight: FontWeight.w600),
      titleMedium: s(size: 16, weight: FontWeight.w600),
      bodyLarge: s(size: 15, weight: FontWeight.w500, color: colors.textPrimary),
      bodyMedium: s(size: 14, weight: FontWeight.w500, color: colors.textPrimary),
      bodySmall: s(size: 14, weight: FontWeight.w500, color: colors.textSecondary),
      labelLarge: s(size: 14, weight: FontWeight.w600),
      labelMedium: s(size: 13, weight: FontWeight.w600, color: colors.textSecondary),
      labelSmall: s(size: 12, weight: FontWeight.w500, color: colors.textMuted),
    );
  }

  static TextStyle balance(AppThemeExtension colors, {Color? color}) =>
      _style(
        size: 32,
        weight: FontWeight.w800,
        color: color ?? colors.textPrimary,
        letterSpacing: -0.3,
        height: 1.1,
      );

  static TextStyle moneyLabel(AppThemeExtension colors) => _style(
        size: 13,
        weight: FontWeight.w600,
        color: colors.textSecondary,
        letterSpacing: 0,
      );

  static TextStyle profitChange({required bool isPositive}) => _style(
        size: 13,
        weight: FontWeight.w700,
        color: isPositive ? AppColors.green : AppColors.red,
        letterSpacing: -0.1,
      );

  static TextStyle sectionTitle(AppThemeExtension colors) => _style(
        size: 17,
        weight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: -0.2,
      );
}
