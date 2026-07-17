import 'package:flutter/material.dart';

import '../../features/stocks/presentation/widgets/candlestick_chart.dart';
import '../../models/stock_model.dart';
import '../theme/theme_a.dart';
import 'tradingview_config.dart';
import 'tradingview_symbols.dart';

import 'tradingview_platform_stub.dart'
    if (dart.library.html) 'tradingview_platform_web.dart'
    if (dart.library.io) 'tradingview_platform_mobile.dart';

/// Candlestick chart powered by TradingView embed (web + mobile) with backend candle fallback.
class TradingViewChart extends StatelessWidget {
  final String symbol;
  final String intervalLabel;
  final String? apiInterval;
  final String exchange;
  final bool isCommodity;
  final double height;
  final List<CandleModel>? fallbackCandles;
  final bool isLoading;

  const TradingViewChart({
    super.key,
    required this.symbol,
    required this.intervalLabel,
    this.apiInterval,
    this.exchange = 'NSE',
    this.isCommodity = false,
    this.height = 280,
    this.fallbackCandles,
    this.isLoading = false,
  });

  String get _tvSymbol => isCommodity
      ? TradingViewSymbols.commodity(symbol)
      : TradingViewSymbols.stock(symbol, exchange: exchange);

  String get _tvInterval {
    if (apiInterval != null && apiInterval!.isNotEmpty) {
      return TradingViewSymbols.intervalForApi(apiInterval!);
    }
    return TradingViewSymbols.intervalForLabel(intervalLabel);
  }

  /// Free TradingView embeds block most NSE/BSE equities with
  /// "This symbol is only available on TradingView" — use our candle data instead.
  bool get _preferNativeChart {
    if (!TradingViewConfig.isEnabled) return true;
    if (isCommodity) return false;
    final ex = exchange.toUpperCase().trim();
    return ex == 'NSE' || ex == 'BSE' || ex.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = p.isDark ? 'dark' : 'light';

    if (!_preferNativeChart) {
      return Stack(
        children: [
          TradingViewPlatformChart(
            tvSymbol: _tvSymbol,
            interval: _tvInterval,
            height: height,
            theme: theme,
          ),
          if (isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: p.bg.withValues(alpha: 0.35),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: p.primary),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final candles = fallbackCandles ?? const <CandleModel>[];
    if (isLoading && candles.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: p.primary),
          ),
        ),
      );
    }

    if (candles.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Chart loading…',
            style: ThemeAType.secondary(size: 14, color: p.textGrey),
          ),
        ),
      );
    }

    return CandlestickChart(candles: candles, height: height);
  }
}
