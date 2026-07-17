import 'package:flutter/material.dart';

import '../../features/stocks/presentation/widgets/candlestick_chart.dart';
import '../../models/stock_model.dart';
import 'tradingview_charting_library_placeholder.dart';
import 'tradingview_config.dart';

/// Fallback when TradingView embed is unavailable on this platform.
class TradingViewPlatformChart extends StatelessWidget {
  final String tvSymbol;
  final String interval;
  final double height;
  final String theme;
  final List<CandleModel>? fallbackCandles;

  const TradingViewPlatformChart({
    super.key,
    required this.tvSymbol,
    required this.interval,
    required this.height,
    this.theme = 'dark',
    this.fallbackCandles,
  });

  @override
  Widget build(BuildContext context) {
    if (TradingViewConfig.usesChartingLibrary) {
      return TradingViewChartingLibraryPlaceholder(height: height);
    }

    final candles = fallbackCandles ?? const <CandleModel>[];
    if (candles.length >= 2) {
      return CandlestickChart(candles: candles, height: height);
    }

    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          'Chart unavailable on this platform',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
