import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme_extension.dart';
import 'colors.dart';

/// Universal app backdrop — pale lime (light) or black (dark).
class PremiumAppBackdrop extends StatelessWidget {
  final Widget child;
  final int glowVariant;

  const PremiumAppBackdrop({
    super.key,
    required this.child,
    this.glowVariant = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.background,
      child: child,
    );
  }
}

/// Animated mesh glow for auth / AI screens.
class PremiumMeshBackground extends StatefulWidget {
  final int glowVariant;
  final Color? glowPrimary;
  final Color? glowSecondary;

  const PremiumMeshBackground({
    super.key,
    this.glowVariant = 0,
    this.glowPrimary,
    this.glowSecondary,
  });

  @override
  State<PremiumMeshBackground> createState() => _PremiumMeshBackgroundState();
}

class _PremiumMeshBackgroundState extends State<PremiumMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.glowPrimary ?? AppColors.brandPrimary;
    final secondary = widget.glowSecondary ?? AppColors.brandPink;
    final base = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF4F4F0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: base),
            Positioned(
              top: -140 + t * 30,
              left: -100,
              right: -40,
              height: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.1,
                    colors: [
                      primary.withValues(alpha: isDark ? 0.38 : 0.28),
                      primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -160 + (1 - t) * 30,
              right: -100,
              left: -40,
              height: 380,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomRight,
                    radius: 1.1,
                    colors: [
                      secondary.withValues(alpha: isDark ? 0.30 : 0.22),
                      secondary.withValues(alpha: isDark ? 0.10 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PremiumFilmGrain extends StatelessWidget {
  const PremiumFilmGrain({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PremiumNoisePainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _PremiumNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final random = math.Random(42);
    for (var i = 0; i < 120; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
