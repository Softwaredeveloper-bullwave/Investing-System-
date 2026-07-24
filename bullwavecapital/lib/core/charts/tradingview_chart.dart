import 'package:flutter/material.dart';

import '../../features/stocks/presentation/widgets/candlestick_chart.dart';
import '../../models/stock_model.dart';
import '../theme/theme_a.dart';
import 'tradingview_symbols.dart';

import 'tradingview_platform_stub.dart'
    if (dart.library.html) 'tradingview_platform_web.dart'
    if (dart.library.io) 'tradingview_platform_mobile.dart';

/// One consistent candlestick chart used everywhere in the app — see
/// `_preferNativeChart` below. The TradingView web/mobile embed path is kept
/// in this file (dead code, `_preferNativeChart` always returns true now)
/// only in case it's ever worth re-enabling for a specific symbol class;
/// nothing currently routes through it.
class TradingViewChart extends StatelessWidget {
  final String symbol;
  final String intervalLabel;
  final String? apiInterval;
  final String exchange;
  final bool isCommodity;
  final double height;
  final List<CandleModel>? fallbackCandles;
  final bool isLoading;
  final ChartStyle style;
  final bool showMA9;
  final bool showMA21;
  final bool showVolume;

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
    this.style = ChartStyle.candle,
    this.showMA9 = true,
    this.showMA21 = true,
    this.showVolume = true,
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

  /// Always use our own native candlestick chart — one consistent chart
  /// everywhere in the app (equities, indices, commodities), instead of
  /// mixing in the TradingView web/iframe embed. The embed was unreliable
  /// (free TradingView blocks most NSE/BSE symbols outright, and even for
  /// symbols it does allow — like commodities — it can hang on a loading
  /// spinner depending on network/CDN conditions). The native chart renders
  /// instantly from data we already fetch, supports pan/zoom/crosshair, and
  /// now draws MA9/MA21 indicators + volume, matching what the embed would
  /// have shown anyway.
  bool get _preferNativeChart => true;

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

    return CandlestickChart(
      candles: candles,
      height: height,
      style: style,
      showMA9: showMA9,
      showMA21: showMA21,
      showVolume: showVolume,
    );
  }
}
