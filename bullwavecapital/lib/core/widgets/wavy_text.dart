import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Official AI assistant display name.
const String kWavyChatbotName = 'Wavy';

/// Straight, readable brand label with a subtle wavy underline accent.
class WavyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final Color? underlineColor;
  final bool showUnderline;

  const WavyText({
    super.key,
    required this.text,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w800,
    required this.color,
    this.underlineColor,
    this.showUnderline = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = underlineColor ?? color.withValues(alpha: 0.55);
    final style = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.1,
      letterSpacing: -0.3,
    );

    return CustomPaint(
      painter: showUnderline
          ? _WavyUnderlinePainter(
              color: accent,
              waveHeight: (fontSize * 0.12).clamp(1.5, 4.0),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.only(bottom: showUnderline ? fontSize * 0.22 : 0),
        child: Text(text, style: style),
      ),
    );
  }
}

class _WavyUnderlinePainter extends CustomPainter {
  final Color color;
  final double waveHeight;

  _WavyUnderlinePainter({
    required this.color,
    required this.waveHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    final path = Path();
    final baseline = size.height - 1;
    const steps = 24;

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final y = baseline + math.sin(t * math.pi * 2.2) * waveHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavyUnderlinePainter old) =>
      old.color != color || old.waveHeight != waveHeight;
}
