import 'package:flutter/material.dart';

/// Small circular progress ring used for portfolio-allocation style cards.
/// Draws a faint track circle plus a colored progress arc, with the
/// percentage rendered in the center.
class DonutRingChart extends StatelessWidget {
  final double percent; // 0-100
  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const DonutRingChart({
    super.key,
    required this.percent,
    required this.color,
    required this.trackColor,
    this.size = 56,
    this.strokeWidth = 6,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              percent: percent.clamp(0, 100),
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.percent,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.2832, false, trackPaint);

    final sweep = (percent / 100) * 6.28318530718;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const start = -1.5707963268; // -90deg, start at top
    canvas.drawArc(rect, start, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
