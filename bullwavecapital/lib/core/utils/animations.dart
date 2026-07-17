import 'package:flutter/material.dart';

class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);

  static Widget fadeIn({
    required Widget child,
    Duration duration = normal,
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: child,
      ),
      child: child,
    );
  }

  static Widget slideUp({
    required Widget child,
    Duration duration = normal,
    double offset = 30,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: offset, end: 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, value),
        child: Opacity(
          opacity: 1 - (value / offset).clamp(0, 1),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class ResponsiveHelper {
  ResponsiveHelper._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static double contentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 800;
    if (width >= 600) return 600;
    return width;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}
