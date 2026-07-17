import 'package:flutter/material.dart';

/// BullWave Aurora — midnight ocean + electric teal + aurora violet + sunset gold.
class AppColors {
  AppColors._();

  // ── Brand (Neobank lime) ──
  static const Color brandPrimary = Color(0xFFC6FF00);
  static const Color brandPrimaryDark = Color(0xFF0A0A0A);
  static const Color brandPrimaryLight = Color(0xFFF0FFD6);
  static const Color brandPink = Color(0xFFFF6B9D);
  static const Color brandPinkLight = Color(0xFFFF8FB3);
  static const Color brandMagenta = Color(0xFFA855F7);
  static const Color brandGold = Color(0xFFFFB830);

  // Aliases used across the app
  static const Color brandOrange = brandGold;
  static const Color brandOrangeDark = Color(0xFFE6A020);
  static const Color brandOrangeLight = Color(0xFFFFD060);
  static const Color brandPurple = brandMagenta;
  static const Color brandTeal = brandPrimary;
  static const Color brandCyan = Color(0xFF00E8FF);

  // ── Surfaces (midnight ocean) ──
  static const Color background = Color(0xFF060A14);
  static const Color backgroundElevated = Color(0xFF0A1020);
  static const Color surface = Color(0xFF0F1628);
  static const Color surfaceSecondary = Color(0xFF151E32);
  static const Color surfaceHighlight = Color(0xFF1C2844);
  static const Color border = Color(0xFF243050);
  static const Color borderSubtle = Color(0xFF1A2440);

  // ── Semantic ──
  static const Color green = Color(0xFF16A34A);
  static const Color greenSoft = Color(0xFFF0FFD6);
  static const Color greenDark = Color(0xFF365314);
  static const Color red = Color(0xFFF87171);
  static const Color warningRed = red;
  static const Color blue = Color(0xFF4D9FFF);
  static const Color yellow = brandGold;
  static const Color warningAmber = brandGold;
  static const Color secondary = Color(0xFF627DFF);

  // ── Commodity categories ──
  static const Color commodityGold = brandGold;
  static const Color commoditySilver = Color(0xFFCBD5E1);
  static const Color commodityEnergy = Color(0xFFFB923C);
  static const Color commodityMetal = brandCyan;

  // ── Text ──
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4C0D4);
  static const Color textMuted = Color(0xFF6B7A94);
  static const Color textDisabled = Color(0xFF4A5568);

  // ── Aliases ──
  static const Color primary = brandPrimary;
  static const Color accent = brandPink;
  static const Color accentLight = brandPinkLight;
  static const Color primaryLight = surfaceSecondary;
  static const Color primaryDark = background;
  static const Color card = surface;
  static const Color profit = green;
  static const Color loss = red;
  static const Color success = green;
  static const Color error = red;
  static const Color warning = yellow;
  static const Color textHint = textMuted;
  static const Color shimmerBase = surfaceSecondary;
  static const Color shimmerHighlight = surfaceHighlight;

  static const LinearGradient heroGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D4AA), Color(0xFF627DFF)],
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C1830), Color(0xFF060A14)],
  );

  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF060A14), Color(0xFF0A1020)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, Color(0xFF627DFF)],
  );

  static const LinearGradient primaryGradient = accentGradient;

  static const LinearGradient portfolioCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF152040),
      Color(0xFF0F1628),
      Color(0xFF0A2018),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient aiInsightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1040),
      Color(0xFF627DFF),
      Color(0xFF00A88A),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient profileHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF152040),
      Color(0xFF627DFF),
      Color(0xFF00D4AA),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient pinkPurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D4AA), Color(0xFF627DFF), Color(0xFFFF6B9D)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient onboardingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF152040), Color(0xFF627DFF), Color(0xFF00D4AA)],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient commodityHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF152040), Color(0xFF060A14)],
  );

  static const LinearGradient chartFillGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x4000D4AA), Color(0x0000D4AA)],
  );

  static const LinearGradient greenGlowGradient = LinearGradient(
    colors: [Color(0x3300E676), Color(0x0000E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient paytmHeaderGradient = accentGradient;

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF152040), Color(0xFF627DFF), Color(0xFF00D4AA)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient navGlow = LinearGradient(
    colors: [Color(0x4000D4AA), Color(0x00627DFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient aiBuddyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1D4ED8),
      Color(0xFF2563EB),
      Color(0xFF0EA5E9),
      Color(0xFF38BDF8),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  static const Color aiBuddyLime = brandCyan;

  // Per-tab nav accent gradients
  static const LinearGradient navHomeGradient = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF00E8FF)],
  );
  static const LinearGradient navMarketsGradient = LinearGradient(
    colors: [Color(0xFF627DFF), Color(0xFFA855F7)],
  );
  static const LinearGradient navPortfolioGradient = LinearGradient(
    colors: [Color(0xFFFFB830), Color(0xFFFF6B9D)],
  );
  static const LinearGradient navWalletGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00D4AA)],
  );
  static const LinearGradient navProfileGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF627DFF)],
  );

  // Light mode explore card tokens
  static const Color exploreCardBackground = Color(0xFFFFFFFF);
  static const Color exploreCardTint = Color(0xFFF0FFD6);
  static const Color exploreLabelMuted = Color(0xFF737373);
  static const Color exploreLabelPrimary = Color(0xFF000000);
}
