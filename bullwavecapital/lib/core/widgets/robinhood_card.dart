import 'package:flutter/material.dart';
import '../constants/dimensions.dart';
import 'premium_ui_kit.dart';

class RobinhoodCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool glow;
  final Color? glowColor;

  const RobinhoodCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingMd),
      onTap: onTap,
      glow: glow,
      glowColor: glowColor,
      child: child,
    );
  }
}
