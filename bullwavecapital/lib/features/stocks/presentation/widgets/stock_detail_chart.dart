import 'package:flutter/material.dart';

import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../models/stock_model.dart';
import 'candlestick_chart.dart' show ChartStyle;

/// Interval label shown in UI → backend candle interval.
const stockChartIntervals = <({String label, String apiInterval})>[
  (label: '1m', apiInterval: '1m'),
  (label: '5m', apiInterval: '5m'),
  (label: '30m', apiInterval: '30m'),
  (label: '1H', apiInterval: '1h'),
  (label: '1D', apiInterval: '1d'),
  (label: '1M', apiInterval: '90d'),
];

/// Dhan-style chart card: a compact toolbar (interval chips, chart-type
/// toggle, Indicators picker) sitting directly above the plot — matching
/// Dhan's own chart header layout — instead of a plain interval row below
/// a bare chart.
class StockDetailChart extends StatefulWidget {
  final String symbol;
  final String exchange;
  final List<CandleModel> candles;
  final bool isLoading;
  final String selectedLabel;
  final ValueChanged<String> onIntervalSelected;

  const StockDetailChart({
    super.key,
    required this.symbol,
    this.exchange = 'NSE',
    required this.candles,
    required this.isLoading,
    required this.selectedLabel,
    required this.onIntervalSelected,
  });

  @override
  State<StockDetailChart> createState() => _StockDetailChartState();
}

class _StockDetailChartState extends State<StockDetailChart> {
  ChartStyle _style = ChartStyle.candle;
  bool _showMA9 = true;
  bool _showMA21 = true;
  bool _showVolume = true;

  String get _apiInterval {
    for (final item in stockChartIntervals) {
      if (item.label == widget.selectedLabel) return item.apiInterval;
    }
    return '1d';
  }

  Future<void> _openIndicators() async {
    final colors = context.appColors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Indicators', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Overlaid on the price chart', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('MA9 (fast)'),
                      subtitle: const Text('9-period moving average'),
                      value: _showMA9,
                      onChanged: (v) => setSheetState(() => setState(() => _showMA9 = v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('MA21 (slow)'),
                      subtitle: const Text('21-period moving average'),
                      value: _showMA21,
                      onChanged: (v) => setSheetState(() => setState(() => _showMA21 = v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Volume'),
                      subtitle: const Text('Volume bars below the price plot'),
                      value: _showVolume,
                      onChanged: (v) => setSheetState(() => setState(() => _showVolume = v)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartTopToolbar(
            selectedLabel: widget.selectedLabel,
            onIntervalSelected: widget.onIntervalSelected,
            style: _style,
            onStyleChanged: (s) => setState(() => _style = s),
            onIndicatorsTap: _openIndicators,
          ),
          Divider(height: 1, color: colors.border),
          TradingViewChart(
            symbol: widget.symbol,
            exchange: widget.exchange,
            intervalLabel: widget.selectedLabel,
            apiInterval: _apiInterval,
            fallbackCandles: widget.candles,
            isLoading: widget.isLoading,
            height: 340,
            style: _style,
            showMA9: _showMA9,
            showMA21: _showMA21,
            showVolume: _showVolume,
          ),
        ],
      ),
    );
  }
}

/// Compact toolbar matching Dhan's chart header: interval chips on the
/// left, a chart-type toggle and an Indicators picker on the right.
class _ChartTopToolbar extends StatelessWidget {
  final String selectedLabel;
  final ValueChanged<String> onIntervalSelected;
  final ChartStyle style;
  final ValueChanged<ChartStyle> onStyleChanged;
  final VoidCallback onIndicatorsTap;

  const _ChartTopToolbar({
    required this.selectedLabel,
    required this.onIntervalSelected,
    required this.style,
    required this.onStyleChanged,
    required this.onIndicatorsTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // The whole strip (interval chips + style toggle + Indicators button) is
    // ONE horizontally-scrollable row with mainAxisSize.min, rather than an
    // Expanded chip section next to fixed-width siblings. That previous
    // layout assumed there'd always be enough leftover width for the
    // fixed-width tail (divider + icon + divider + "Indicators"), which
    // isn't guaranteed on narrower viewports (e.g. a resized Chrome window)
    // or mid-transition — causing a RenderFlex overflow. Making everything
    // scroll together makes overflow impossible: if content doesn't fit, it
    // scrolls instead of overflowing.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in stockChartIntervals)
              _IntervalChip(
                label: item.label,
                selected: item.label == selectedLabel,
                onTap: () => onIntervalSelected(item.label),
              ),
            Container(width: 1, height: 22, color: colors.border, margin: const EdgeInsets.symmetric(horizontal: 4)),
            Tooltip(
              message: style == ChartStyle.candle ? 'Switch to line chart' : 'Switch to candles',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onStyleChanged(style == ChartStyle.candle ? ChartStyle.line : ChartStyle.candle),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    style == ChartStyle.candle ? Icons.candlestick_chart_rounded : Icons.show_chart_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 22, color: colors.border, margin: const EdgeInsets.symmetric(horizontal: 4)),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onIndicatorsTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stacked_line_chart_rounded, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Indicators', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IntervalChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? colors.primary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
