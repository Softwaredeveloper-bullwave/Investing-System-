import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';

export '../../../../core/theme/theme_a.dart';

/// Home screen theme tokens — use [of] for dark/light aware colors.
class HomeThemeA {
  HomeThemeA._();

  static ThemePalette of(BuildContext context) => ThemeA.of(context);

  static const bg = ThemeA.bg;
  static const primary = ThemeA.primary;
  static const primaryDark = ThemeA.primaryDark;
  static const walletAccent = ThemeA.walletAccent;
  static const primaryLight = ThemeA.primaryLight;
  static const iconBg = ThemeA.iconBg;
  static const iconBorder = ThemeA.iconBorder;
  static const textDark = ThemeA.textDark;
  static const textGrey = ThemeA.textGrey;
  static const textMuted = ThemeA.textMuted;
  static const card = ThemeA.card;
  static const borderLight = ThemeA.borderLight;
  static const positive = ThemeA.positive;
  static const negative = ThemeA.negative;
  static const cardRadius = ThemeA.cardRadius;

  static BoxDecoration cardDecoration(BuildContext context, {Color? shadowTint}) =>
      of(context).cardDecoration(shadowTint: shadowTint);

  static BoxDecoration iconCircleDecoration(
    BuildContext context, {
    Color? borderColor,
    Color? backgroundColor,
  }) =>
      of(context).iconCircleDecoration(borderColor: borderColor, backgroundColor: backgroundColor);
}

typedef HomeSectionHeader = AppSectionHeader;
