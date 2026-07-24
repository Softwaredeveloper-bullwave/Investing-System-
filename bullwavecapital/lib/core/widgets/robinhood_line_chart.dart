import 'package:flutter/material.dart';
import '../theme/colors.dart';

class RobinhoodLineChart extends StatelessWidget {
  final List<double> values;
  final double height;
  final bool isPositive;

  /// Optional overrides for use on dark/colored backgrounds (e.g. the
  /// forest-green hero card), where a bright glowing line reads better
  /// than the standard green/red semantic colors.
  final Color? lineColorOverride;
  final Color? fillColorOverride;

  const RobinhoodLineChart({
    super.key,
    required this.values,
    this.height = 120,
    this.isPositive = true,
    this.lineColorOverride,
    this.fillColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          lineColor: lineColorOverride ?? (isPositive ? AppColors.green : AppColors.red),
          isPositiveLine: isPositive,
          fillColorOverride: fillColorOverride,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final bool isPositiveLine;
  final Color? fillColorOverride;

  _LineChartPainter({
    required this.values,
    required this.lineColor,
    this.isPositiveLine = true,
    this.fillColorOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).clamp(1, double.infinity);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - min) / range) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (values.length - 1)) * size.width;
        final prevY = size.height - ((values[i - 1] - min) / range) * (size.height - 8) - 4;
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
        fillPath.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isPositiveLine
            ? [
                (fillColorOverride ?? AppColors.brandMint).withValues(alpha: 0.35),
                (fillColorOverride ?? AppColors.brandMint).withValues(alpha: 0.08),
                lineColor.withValues(alpha: 0.0),
              ]
            : [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.0)],
        stops: isPositiveLine ? const [0.0, 0.55, 1.0] : null,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}
