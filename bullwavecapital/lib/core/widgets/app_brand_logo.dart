import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/assets.dart';
import '../theme/colors.dart';

/// Symmetric BullWave mark — splash, login, headers.
class AppBrandLogo extends StatelessWidget {
  final double size;
  final bool showShadow;
  final bool rounded;

  const AppBrandLogo({
    super.key,
    this.size = 72,
    this.showShadow = true,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = rounded ? size * 0.28 : 0.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.brandPink.withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          AppAssets.logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Full CBW wordmark (horns + fang + lettering) — splash and onboarding hero art.
/// Unlike [AppBrandLogo] this isn't clipped to a square badge; it keeps its
/// natural taller-than-wide proportions.
class AppBrandWordmark extends StatelessWidget {
  final double width;
  final bool showGlow;

  const AppBrandWordmark({
    super.key,
    this.width = 180,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    // The source artwork is a square badge on a solid black canvas, so it
    // gets the same rounded-card treatment as [AppBrandLogo] — that keeps it
    // reading as an intentional dark mark on both light and dark screens
    // instead of a hard-edged square.
    final radius = width * 0.16;
    final badge = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        AppAssets.cbwWordmark,
        width: width,
        fit: BoxFit.contain,
      ),
    );

    if (!showGlow) return badge;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPink.withValues(alpha: 0.30),
            blurRadius: width * 0.4,
            spreadRadius: width * 0.02,
          ),
        ],
      ),
      child: badge,
    );
  }
}

/// Tintable SVG glyph for navigation and inline UI.
class AppSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final Gradient? gradient;

  const AppSvgIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: gradient == null && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );

    if (gradient == null) return picture;

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient!.createShader(bounds),
      child: picture,
    );
  }
}
