import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../models/stock_model.dart';

/// Drawing tools available on the side toolbar, TradingView-style.
enum _DrawTool { none, trendLine, horizontalLine, fibonacci, rectangle }

class _Drawing {
  final _DrawTool tool;
  Offset start; // fractional (0..1) within the plot rect
  Offset end;

  _Drawing({required this.tool, required this.start, required this.end});
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtAxisDate(DateTime t, bool intraday) {
  if (intraday) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${t.day} ${_monthAbbr[t.month - 1]}';
}

String _fmtPrice(double v) {
  if (v >= 1000) {
    return v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
        );
  }
  return v.toStringAsFixed(2);
}

const int _minVisibleCandles = 12;
const int _defaultVisibleCandles = 44;

/// Candle body vs. a Dhan-style filled area/line plot.
enum ChartStyle { candle, line }

/// A TradingView/Groww/Dhan-style candlestick chart: price/time axes, grid,
/// pinch-to-zoom + drag-to-pan viewport, a long-press crosshair with an OHLC
/// readout, a sticky live-price line, a volume strip, and a side drawing
/// toolbar (trend line, horizontal ray, fibonacci, rectangle).
class CandlestickChart extends StatefulWidget {
  final List<CandleModel> candles;
  final double height;
  final ChartStyle style;
  final bool showMA9;
  final bool showMA21;
  final bool showVolume;

  const CandlestickChart({
    super.key,
    required this.candles,
    this.height = 220,
    this.style = ChartStyle.candle,
    this.showMA9 = true,
    this.showMA21 = true,
    this.showVolume = true,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart>
    with SingleTickerProviderStateMixin {
  _DrawTool _tool = _DrawTool.none;
  final List<_Drawing> _drawings = [];
  _Drawing? _active;
  Offset? _crosshair;
  Rect _plotRect = Rect.zero;

  // ── Viewport (pan + zoom) ──
  int _visibleCount = _defaultVisibleCandles;
  int _endIndex = 0; // index (into widget.candles) of the right-most visible candle
  bool _followLive = true;

  int _gestureStartVisibleCount = _defaultVisibleCandles;
  int _gestureStartEndIndex = 0;
  double _gestureStartFocalDx = 0;
  double _lastSlotWidth = 12;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _resetViewport();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void didUpdateWidget(CandlestickChart old) {
    super.didUpdateWidget(old);
    final total = widget.candles.length;
    if (total == 0) return;
    if (old.candles.length != total) {
      // New candle data arrived (live update / interval change / more history
      // loaded). If the user hadn't panned away from the live edge, keep the
      // viewport pinned to the newest candle so the chart appears to grow.
      _visibleCount = _visibleCount.clamp(_minVisibleCandles, total);
      if (_followLive) {
        _endIndex = total - 1;
      } else {
        _endIndex = _endIndex.clamp(_visibleCount - 1, total - 1);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _resetViewport() {
    final total = widget.candles.length;
    _visibleCount = total == 0 ? _defaultVisibleCandles : total.clamp(_minVisibleCandles, _defaultVisibleCandles);
    _endIndex = total == 0 ? 0 : total - 1;
    _followLive = true;
  }

  void _selectTool(_DrawTool tool) {
    setState(() {
      _tool = tool == _tool ? _DrawTool.none : tool;
      _crosshair = null;
    });
  }

  void _clearDrawings() => setState(_drawings.clear);

  // ── Explicit zoom buttons — same viewport math as pinch-zoom, but a
  // reliable tap target for devices/testers without multi-touch. ──
  void _zoomIn() {
    final total = widget.candles.length;
    if (total == 0) return;
    setState(() {
      _visibleCount = (_visibleCount * 0.75).round().clamp(_minVisibleCandles, total);
      _endIndex = _endIndex.clamp(_visibleCount - 1, total - 1);
      _followLive = _endIndex >= total - 1;
    });
  }

  void _zoomOut() {
    final total = widget.candles.length;
    if (total == 0) return;
    setState(() {
      _visibleCount = (_visibleCount * 1.35).round().clamp(_minVisibleCandles, total);
      _endIndex = _endIndex.clamp(_visibleCount - 1, total - 1);
      _followLive = _endIndex >= total - 1;
    });
  }

  Offset? _toFractional(Offset local) {
    if (_plotRect.width <= 0 || _plotRect.height <= 0) return null;
    final dx = ((local.dx - _plotRect.left) / _plotRect.width).clamp(0.0, 1.0);
    final dy = ((local.dy - _plotRect.top) / _plotRect.height).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }

  // ── Combined pan + pinch-zoom (or drawing, when a tool is active) ──
  void _onScaleStart(ScaleStartDetails d) {
    if (_tool != _DrawTool.none) {
      final frac = _toFractional(d.localFocalPoint);
      if (frac == null) return;
      setState(() => _active = _Drawing(tool: _tool, start: frac, end: frac));
      return;
    }
    _gestureStartVisibleCount = _visibleCount;
    _gestureStartEndIndex = _endIndex;
    _gestureStartFocalDx = d.localFocalPoint.dx;
    if (_crosshair != null) {
      setState(() => _crosshair = null);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_tool != _DrawTool.none) {
      final frac = _toFractional(d.localFocalPoint);
      if (frac == null || _active == null) return;
      setState(() => _active!.end = frac);
      return;
    }

    final total = widget.candles.length;
    if (total == 0) return;

    var newVisibleCount = _gestureStartVisibleCount;
    if ((d.scale - 1.0).abs() > 0.01) {
      newVisibleCount = (_gestureStartVisibleCount / d.scale).round().clamp(_minVisibleCandles, total);
    }

    final slotWidth = _lastSlotWidth > 0 ? _lastSlotWidth : 12.0;
    final totalDx = d.localFocalPoint.dx - _gestureStartFocalDx;
    final candleShift = (totalDx / slotWidth).round();
    final newEndIndex = (_gestureStartEndIndex - candleShift).clamp(newVisibleCount - 1, total - 1);

    setState(() {
      _visibleCount = newVisibleCount;
      _endIndex = newEndIndex;
      _followLive = _endIndex >= total - 1;
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_active == null) return;
    setState(() {
      _drawings.add(_active!);
      _active = null;
      _tool = _DrawTool.none;
    });
  }

  void _onDoubleTap() {
    setState(() {
      _resetViewport();
      _crosshair = null;
    });
  }

  // Tap a candle to inspect its OHLC — simpler and more reliable than a
  // long-press-drag (which can fight the pan/zoom recognizer for the same
  // pointer). Tapping the same spot again, or starting a pan/zoom drag,
  // dismisses it.
  void _onTapUp(TapUpDetails d) {
    if (_tool != _DrawTool.none) return;
    setState(() {
      _crosshair = _crosshair == null ? d.localPosition : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (widget.candles.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('No chart data', style: TextStyle(color: p.textMuted)),
        ),
      );
    }

    // The drawing toolbar needs ~300px of vertical room to fit its eight
    // fixed-size (30px) buttons (cursor, trend line, horizontal ray,
    // fibonacci, rectangle, zoom in/out, clear) without overflowing (see
    // the RenderFlex overflow that used to fire on compact embedded charts
    // — paper trading pads, dashboard previews — which pass a much shorter
    // `height` than the full stock-detail chart). Below that threshold,
    // skip the toolbar entirely rather than shrink it into an overflow.
    final showToolbar = widget.height >= 300;

    final total = widget.candles.length;
    final visibleCount = _visibleCount.clamp(_minVisibleCandles, total);
    final endIndex = _endIndex.clamp(visibleCount - 1, total - 1);
    final startIndex = endIndex - visibleCount + 1;
    final visibleCandles = widget.candles.sublist(startIndex, endIndex + 1);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showToolbar) ...[
            _DrawToolbar(
              selected: _tool,
              onSelect: _selectTool,
              onClear: _drawings.isEmpty ? null : _clearDrawings,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              palette: p,
            ),
            Container(width: 1, color: p.borderLight),
          ],
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onDoubleTap: _onDoubleTap,
              onTapUp: _onTapUp,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ProChartPainter(
                      candles: visibleCandles,
                      fullCandles: widget.candles,
                      startIndex: startIndex,
                      latestClose: widget.candles.last.close,
                      livePulse: _pulseController.value,
                      isLiveEdge: _followLive,
                      palette: p,
                      drawings: _drawings,
                      active: _active,
                      crosshair: _crosshair,
                      style: widget.style,
                      showMA9: widget.showMA9,
                      showMA21: widget.showMA21,
                      showVolume: widget.showVolume,
                      onPlotRect: (r) => _plotRect = r,
                      onSlotWidth: (w) => _lastSlotWidth = w,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final ThemePalette palette;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: palette.textGrey),
        ),
      ),
    );
  }
}

class _DrawToolbar extends StatelessWidget {
  final _DrawTool selected;
  final ValueChanged<_DrawTool> onSelect;
  final VoidCallback? onClear;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ThemePalette palette;

  const _DrawToolbar({
    required this.selected,
    required this.onSelect,
    required this.onClear,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Crosshair cursor — same grid-style crosshair icon used by
          // TradingView/Groww/Dhan to represent "tap a candle to inspect".
          _ToolButton(
            icon: Icons.add_box_outlined,
            tooltip: 'Crosshair cursor',
            active: selected == _DrawTool.none,
            palette: palette,
            onTap: () => onSelect(_DrawTool.none),
          ),
          const SizedBox(height: 6),
          _ToolButton(
            icon: Icons.show_chart_rounded,
            tooltip: 'Trend line',
            active: selected == _DrawTool.trendLine,
            palette: palette,
            onTap: () => onSelect(_DrawTool.trendLine),
          ),
          const SizedBox(height: 6),
          _ToolButton(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Horizontal line',
            active: selected == _DrawTool.horizontalLine,
            palette: palette,
            onTap: () => onSelect(_DrawTool.horizontalLine),
          ),
          const SizedBox(height: 6),
          _ToolButton(
            icon: Icons.stacked_line_chart_rounded,
            tooltip: 'Fibonacci',
            active: selected == _DrawTool.fibonacci,
            palette: palette,
            onTap: () => onSelect(_DrawTool.fibonacci),
          ),
          const SizedBox(height: 6),
          _ToolButton(
            icon: Icons.crop_free_rounded,
            tooltip: 'Rectangle',
            active: selected == _DrawTool.rectangle,
            palette: palette,
            onTap: () => onSelect(_DrawTool.rectangle),
          ),
          const Spacer(),
          _ZoomButton(icon: Icons.add_rounded, tooltip: 'Zoom in', palette: palette, onTap: onZoomIn),
          const SizedBox(height: 6),
          _ZoomButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', palette: palette, onTap: onZoomOut),
          const SizedBox(height: 10),
          _ToolButton(
            icon: Icons.layers_clear_rounded,
            tooltip: 'Clear drawings',
            active: false,
            enabled: onClear != null,
            palette: palette,
            onTap: onClear ?? () {},
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final bool enabled;
  final ThemePalette palette;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.palette,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? palette.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: active ? palette.onPrimary : palette.textGrey,
            ),
          ),
        ),
      ),
    );
  }
}

// Indicator colors — kept distinct from the green/red candle + volume
// palette so overlays read clearly, matching the amber/violet moving-average
// convention used by Groww/Dhan/TradingView.
const Color _maFastColor = Color(0xFFF59E0B); // MA9 — amber
const Color _maSlowColor = Color(0xFF8B5CF6); // MA21 — violet

/// Simple moving average over [period] closes ending at (and including)
/// index [i] in [candles]. Returns null if there isn't enough history yet.
double? _smaAt(List<CandleModel> candles, int i, int period) {
  if (i < period - 1) return null;
  var sum = 0.0;
  for (var k = i - period + 1; k <= i; k++) {
    sum += candles[k].close;
  }
  return sum / period;
}

class _ProChartPainter extends CustomPainter {
  final List<CandleModel> candles;
  final List<CandleModel> fullCandles;
  final int startIndex;
  final double latestClose;
  final double livePulse;
  final bool isLiveEdge;
  final ThemePalette palette;
  final List<_Drawing> drawings;
  final _Drawing? active;
  final Offset? crosshair;
  final ChartStyle style;
  final bool showMA9;
  final bool showMA21;
  final bool showVolume;
  final ValueChanged<Rect> onPlotRect;
  final ValueChanged<double> onSlotWidth;

  _ProChartPainter({
    required this.candles,
    required this.fullCandles,
    required this.startIndex,
    required this.latestClose,
    required this.livePulse,
    required this.isLiveEdge,
    required this.palette,
    required this.drawings,
    required this.active,
    required this.crosshair,
    required this.style,
    required this.showMA9,
    required this.showMA21,
    required this.showVolume,
    required this.onPlotRect,
    required this.onSlotWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = candles.length;
    if (count == 0) return;

    const priceAxisWidth = 56.0;
    const timeAxisHeight = 20.0;
    const topPad = 12.0;

    final plotRect = Rect.fromLTWH(
      0,
      topPad,
      size.width - priceAxisWidth,
      size.height - topPad - timeAxisHeight,
    );
    onPlotRect(plotRect);
    if (plotRect.width <= 0 || plotRect.height <= 0) return;

    const gap = 6.0;
    final volumeHeight = showVolume ? plotRect.height * 0.16 : 0.0;
    final candleRect = Rect.fromLTWH(
      plotRect.left,
      plotRect.top,
      plotRect.width,
      plotRect.height - volumeHeight - (showVolume ? gap : 0),
    );
    final volumeRect = Rect.fromLTWH(
      plotRect.left,
      candleRect.bottom + gap,
      plotRect.width,
      volumeHeight,
    );

    final rawMinLow = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final rawMaxHigh = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final rawRange = (rawMaxHigh - rawMinLow) == 0 ? rawMaxHigh * 0.02 + 1 : rawMaxHigh - rawMinLow;
    final pad = rawRange * 0.08;
    final minPrice = rawMinLow - pad;
    final maxPrice = rawMaxHigh + pad;
    final priceRange = maxPrice - minPrice;

    final maxVolume = candles.map((c) => c.volume).fold<int>(0, (a, b) => a > b ? a : b);

    double yOf(double price) =>
        candleRect.bottom - ((price - minPrice) / priceRange) * candleRect.height;
    double priceAt(double y) =>
        maxPrice - ((y - candleRect.top) / candleRect.height) * priceRange;

    final slotWidth = plotRect.width / count;
    onSlotWidth(slotWidth);
    final candleWidth = (slotWidth * 0.62).clamp(1.5, 20.0);
    double xOf(int i) => plotRect.left + slotWidth * i + slotWidth / 2;

    final gridPaint = Paint()
      ..color = palette.borderLight
      ..strokeWidth = 1;
    final axisTextStyle = TextStyle(color: palette.textMuted, fontSize: 10);

    // ── Horizontal price grid + labels ──
    const priceLines = 4;
    for (var i = 0; i <= priceLines; i++) {
      final price = maxPrice - (priceRange / priceLines) * i;
      final y = yOf(price);
      canvas.drawLine(Offset(plotRect.left, y), Offset(plotRect.right, y), gridPaint);
      _paintText(
        canvas,
        _fmtPrice(price),
        Offset(plotRect.right + 6, y - 6),
        axisTextStyle,
      );
    }

    // ── Time axis labels ──
    final intraday = candles.length > 1 &&
        candles.last.time.difference(candles.first.time).inHours < 48;
    const timeTicks = 4;
    for (var i = 0; i <= timeTicks; i++) {
      final idx = ((count - 1) * i / timeTicks).round().clamp(0, count - 1);
      final x = xOf(idx);
      _paintText(
        canvas,
        _fmtAxisDate(candles[idx].time, intraday),
        Offset(x - 16, plotRect.bottom + 4),
        axisTextStyle,
        maxWidth: 44,
      );
    }

    // ── Candles (or a Dhan-style filled line/area plot) ──
    final trendUp = candles.last.close >= candles.first.close;
    final lineColor = trendUp ? palette.positive : palette.negative;

    if (style == ChartStyle.line) {
      final linePath = Path();
      final fillPath = Path();
      for (var i = 0; i < count; i++) {
        final pt = Offset(xOf(i), yOf(candles[i].close));
        if (i == 0) {
          linePath.moveTo(pt.dx, pt.dy);
          fillPath.moveTo(pt.dx, candleRect.bottom);
          fillPath.lineTo(pt.dx, pt.dy);
        } else {
          linePath.lineTo(pt.dx, pt.dy);
          fillPath.lineTo(pt.dx, pt.dy);
        }
      }
      fillPath.lineTo(xOf(count - 1), candleRect.bottom);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lineColor.withValues(alpha: 0.22), lineColor.withValues(alpha: 0.0)],
          ).createShader(candleRect),
      );
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var i = 0; i < count; i++) {
      final c = candles[i];
      final x = xOf(i);
      final bullish = c.isBullish;
      final color = bullish ? palette.positive : palette.negative;

      if (style == ChartStyle.candle) {
        canvas.drawLine(
          Offset(x, yOf(c.high)),
          Offset(x, yOf(c.low)),
          Paint()
            ..color = color
            ..strokeWidth = 1.2,
        );

        final top = yOf(bullish ? c.close : c.open);
        final bottom = yOf(bullish ? c.open : c.close);
        final body = Rect.fromCenter(
          center: Offset(x, (top + bottom) / 2),
          width: candleWidth,
          height: (bottom - top).abs().clamp(1.5, candleRect.height),
        );
        canvas.drawRect(body, Paint()..color = color);
      }

      // ── Volume bar ──
      if (showVolume && maxVolume > 0) {
        final volFrac = c.volume / maxVolume;
        final volTop = volumeRect.bottom - volumeRect.height * volFrac;
        canvas.drawRect(
          Rect.fromLTRB(x - candleWidth / 2, volTop, x + candleWidth / 2, volumeRect.bottom),
          Paint()..color = color.withValues(alpha: 0.45),
        );
      }
    }

    // ── Moving-average indicator overlays (MA9 fast / MA21 slow) — the
    // same at-a-glance trend lines shown on Groww/Dhan/TradingView charts.
    // Computed over the full candle history (not just the visible slice) so
    // the first few visible candles still get a correct average instead of
    // starting from nothing.
    void drawMaLine(int period, Color color) {
      final path = Path();
      var started = false;
      for (var i = 0; i < count; i++) {
        final fullIdx = startIndex + i;
        final ma = _smaAt(fullCandles, fullIdx, period);
        if (ma == null || ma < minPrice || ma > maxPrice) {
          started = false;
          continue;
        }
        final pt = Offset(xOf(i), yOf(ma));
        if (!started) {
          path.moveTo(pt.dx, pt.dy);
          started = true;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }

    if (showMA9 && count >= 9) drawMaLine(9, _maFastColor);
    if (showMA21 && count >= 21) drawMaLine(21, _maSlowColor);
    var legendX = plotRect.left + 4;
    if (showMA9 && count >= 9) {
      _paintText(canvas, 'MA9', Offset(legendX, plotRect.top - 2), TextStyle(color: _maFastColor, fontSize: 9, fontWeight: FontWeight.w700));
      legendX += 30;
    }
    if (showMA21 && count >= 21) {
      _paintText(canvas, 'MA21', Offset(legendX, plotRect.top - 2), TextStyle(color: _maSlowColor, fontSize: 9, fontWeight: FontWeight.w700));
    }

    // ── Sticky live-price line (pinned to the latest known close, shown
    // whenever the crosshair isn't active — mirrors Groww/Dhan's LTP ray) ──
    if (crosshair == null && latestClose >= minPrice && latestClose <= maxPrice) {
      final liveColor = candles.last.isBullish ? palette.positive : palette.negative;
      final y = yOf(latestClose);
      _dashedLine(
        canvas,
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        Paint()
          ..color = liveColor.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      _paintLabelPill(
        canvas,
        _fmtPrice(latestClose),
        Offset(plotRect.right + 2, y - 8),
        liveColor,
        palette.onPrimary,
      );

      // A subtle pulsing glow dot at the right edge signals "live" data,
      // like the animated price tickers in real trading apps.
      if (isLiveEdge) {
        final dotX = xOf(count - 1);
        final pulse = (livePulse * 2 - 1).abs(); // 1 -> 0 -> 1 triangle wave
        final glowRadius = 3.0 + (1 - pulse) * 5.0;
        canvas.drawCircle(
          Offset(dotX, y),
          glowRadius,
          Paint()..color = liveColor.withValues(alpha: (1 - pulse) * 0.35),
        );
        canvas.drawCircle(Offset(dotX, y), 3, Paint()..color = liveColor);
      }
    }

    // ── Drawings (committed + active) ──
    for (final d in drawings) {
      _paintDrawing(canvas, d, candleRect, priceAt);
    }
    if (active != null) {
      _paintDrawing(canvas, active!, candleRect, priceAt);
    }

    // ── Crosshair ──
    if (crosshair != null && candleRect.contains(crosshair!)) {
      final dashPaint = Paint()
        ..color = palette.textGrey.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      _dashedLine(canvas, Offset(crosshair!.dx, plotRect.top), Offset(crosshair!.dx, plotRect.bottom), dashPaint);
      _dashedLine(canvas, Offset(plotRect.left, crosshair!.dy), Offset(plotRect.right, crosshair!.dy), dashPaint);

      // Price label on the right axis.
      final price = priceAt(crosshair!.dy);
      _paintLabelPill(
        canvas,
        _fmtPrice(price),
        Offset(plotRect.right + 2, crosshair!.dy - 8),
        palette.primary,
        palette.onPrimary,
      );

      // Date label on the bottom axis + nearest-candle OHLC card.
      final idx = (((crosshair!.dx - plotRect.left) / slotWidth)).round().clamp(0, count - 1);
      final c = candles[idx];
      _paintLabelPill(
        canvas,
        _fmtAxisDate(c.time, intraday),
        Offset(crosshair!.dx - 22, plotRect.bottom + 2),
        palette.primary,
        palette.onPrimary,
      );

      _paintOhlcCard(canvas, c, palette, Offset(plotRect.left + 4, plotRect.top + 4));
    }
  }

  void _paintDrawing(Canvas canvas, _Drawing d, Rect candleRect, double Function(double) priceAt) {
    Offset abs(Offset frac) => candleRect.topLeft + Offset(frac.dx * candleRect.width, frac.dy * candleRect.height);
    final start = abs(d.start);
    final end = abs(d.end);
    final linePaint = Paint()
      ..color = palette.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    switch (d.tool) {
      case _DrawTool.trendLine:
        canvas.drawLine(start, end, linePaint);
        canvas.drawCircle(start, 3.5, Paint()..color = palette.primary);
        canvas.drawCircle(end, 3.5, Paint()..color = palette.primary);
        break;
      case _DrawTool.horizontalLine:
        canvas.drawLine(
          Offset(candleRect.left, start.dy),
          Offset(candleRect.right, start.dy),
          linePaint,
        );
        _paintLabelPill(
          canvas,
          _fmtPrice(priceAt(start.dy)),
          Offset(candleRect.left + 4, start.dy - 16),
          palette.primary,
          palette.onPrimary,
        );
        break;
      case _DrawTool.rectangle:
        final rect = Rect.fromPoints(start, end);
        canvas.drawRect(rect, Paint()..color = palette.primary.withValues(alpha: 0.12));
        canvas.drawRect(rect, linePaint);
        break;
      case _DrawTool.fibonacci:
        const levels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
        final left = start.dx < end.dx ? start.dx : end.dx;
        final right = start.dx < end.dx ? end.dx : start.dx;
        for (final lvl in levels) {
          final y = start.dy + (end.dy - start.dy) * lvl;
          _dashedLine(
            canvas,
            Offset(left, y),
            Offset(right, y),
            Paint()
              ..color = palette.primary.withValues(alpha: 0.8)
              ..strokeWidth = 1,
          );
          _paintText(
            canvas,
            '${(lvl * 100).toStringAsFixed(1)}% · ${_fmtPrice(priceAt(y))}',
            Offset(right + 4, y - 6),
            TextStyle(color: palette.textGrey, fontSize: 9),
          );
        }
        break;
      case _DrawTool.none:
        break;
    }
  }

  void _paintOhlcCard(Canvas canvas, CandleModel c, ThemePalette palette, Offset at) {
    final bullish = c.isBullish;
    final color = bullish ? palette.positive : palette.negative;
    final text =
        'O ${_fmtPrice(c.open)}   H ${_fmtPrice(c.high)}   L ${_fmtPrice(c.low)}   C ${_fmtPrice(c.close)}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bgRect = Rect.fromLTWH(at.dx, at.dy, painter.width + 12, painter.height + 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
      Paint()..color = palette.card.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
      Paint()
        ..color = palette.borderLight
        ..style = PaintingStyle.stroke,
    );
    painter.paint(canvas, at + const Offset(6, 4));
  }

  void _paintText(Canvas canvas, String text, Offset at, TextStyle style, {double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, at);
  }

  void _paintLabelPill(Canvas canvas, String text, Offset at, Color bg, Color fg) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(at.dx, at.dy, painter.width + 8, painter.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = bg);
    painter.paint(canvas, at + const Offset(4, 2));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 3.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var drawn = 0.0;
    var cur = a;
    while (drawn < total) {
      final segLen = (drawn + dashLen > total) ? total - drawn : dashLen;
      final next = cur + dir * segLen;
      canvas.drawLine(cur, next, paint);
      cur = next + dir * gapLen;
      drawn += segLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _ProChartPainter old) {
    // The active drawing, crosshair, and live pulse are mutated/animated
    // continuously (see _CandlestickChartState), so a field-by-field diff
    // can miss in-progress changes — always repaint, which is cheap at this
    // data size.
    return true;
  }
}
