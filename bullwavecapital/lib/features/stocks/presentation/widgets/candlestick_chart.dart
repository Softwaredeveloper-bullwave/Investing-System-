import 'package:flutter/material.dart';
import '../../../../models/stock_model.dart';
import '../../../../core/theme/colors.dart';

class CandlestickChart extends StatelessWidget {
  final List<CandleModel> candles;
  final double height;

  const CandlestickChart({super.key, required this.candles, this.height = 220});

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('No chart data')));
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CandlePainter(candles: candles),
        size: Size.infinite,
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  final List<CandleModel> candles;

  _CandlePainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    final count = candles.length;
    if (count == 0) return;

    final minLow = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxHigh = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final range = maxHigh - minLow;
    if (range == 0) return;

    final candleWidth = size.width / count * 0.6;
    final gap = size.width / count;

    double yOf(double price) => size.height - ((price - minLow) / range) * (size.height - 16) - 8;

    for (var i = 0; i < count; i++) {
      final c = candles[i];
      final x = gap * i + gap / 2;
      final bullish = c.isBullish;
      final color = bullish ? AppColors.green : AppColors.red;

      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, yOf(c.high)), Offset(x, yOf(c.low)), wickPaint);

      final top = yOf(bullish ? c.close : c.open);
      final bottom = yOf(bullish ? c.open : c.close);
      final body = Rect.fromCenter(
        center: Offset(x, (top + bottom) / 2),
        width: candleWidth,
        height: (bottom - top).abs().clamp(2, size.height),
      );
      canvas.drawRect(body, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) => old.candles != candles;
}
