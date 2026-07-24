import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../models/stock_model.dart';
import '../provider/paper_trading_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../widgets/simulation_badge.dart';

/// Fast, focused one-symbol trading screen for rapid in-and-out ("scalp")
/// trades: a ticking live price + mini chart, one-tap Buy/Sell with preset
/// lot sizes, an optional auto square-off (SL/target), and a running
/// session scoreboard (trade count + realized P&L). Paper-trading only —
/// executes through [PaperTradingProvider.placeOrder] against the virtual
/// wallet, never real money.
class ScalpingScreen extends StatefulWidget {
  final String? initialSymbol;

  const ScalpingScreen({super.key, this.initialSymbol});

  @override
  State<ScalpingScreen> createState() => _ScalpingScreenState();
}

class _ScalpingScreenState extends State<ScalpingScreen> {
  final _symbolController = TextEditingController();
  final _slController = TextEditingController();
  final _targetController = TextEditingController();

  String? _symbol;
  int _qty = 1;
  bool _loadingQuote = false;
  bool _placing = false;
  Timer? _tickTimer;

  // ── Session-local position + P&L tracking (average-cost method) ──
  int _positionQty = 0; // net open quantity for _symbol this session (long only)
  double _avgPrice = 0;
  double _realizedPnl = 0;
  double _totalCharges = 0;
  int _tradeCount = 0;
  bool _autoSquareOffArmed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSymbol != null && widget.initialSymbol!.isNotEmpty) {
      _symbolController.text = widget.initialSymbol!.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSymbol());
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _symbolController.dispose();
    _slController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadSymbol() async {
    final sym = _symbolController.text.trim().toUpperCase();
    if (sym.isEmpty) return;
    setState(() {
      _symbol = sym;
      _loadingQuote = true;
      // New symbol — reset the session scoreboard so P&L only reflects
      // trades on the symbol currently being scalped.
      _positionQty = 0;
      _avgPrice = 0;
      _realizedPnl = 0;
      _totalCharges = 0;
      _tradeCount = 0;
    });
    final market = context.read<StockMarketProvider>();
    await Future.wait([
      market.refreshQuote(sym),
      market.loadCandles(sym, interval: '1m'),
    ]);
    if (!mounted) return;
    setState(() => _loadingQuote = false);
    _startTicking();
  }

  void _startTicking() {
    _tickTimer?.cancel();
    var tick = 0;
    _tickTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final sym = _symbol;
      if (sym == null || !mounted) return;
      final market = context.read<StockMarketProvider>();
      final stock = await market.refreshQuote(sym);
      // Real-time candle formation on the mini chart too — refresh the
      // 1m candle series every ~9s (every 3rd tick) so the current bar
      // visibly updates without hammering the API every 3s.
      tick++;
      if (tick % 3 == 0) unawaited(market.loadCandles(sym, interval: '1m'));
      if (!mounted || stock == null) return;
      _checkAutoSquareOff(stock.ltp);
    });
  }

  void _checkAutoSquareOff(double ltp) {
    if (!_autoSquareOffArmed || _positionQty <= 0) return;
    final sl = double.tryParse(_slController.text.trim());
    final target = double.tryParse(_targetController.text.trim());
    final hitSl = sl != null && sl > 0 && ltp <= sl;
    final hitTarget = target != null && target > 0 && ltp >= target;
    if (hitSl || hitTarget) {
      _executeTrade('SELL', _positionQty, auto: true, reason: hitSl ? 'stop-loss' : 'target');
    }
  }

  Future<void> _executeTrade(String side, int qty, {bool auto = false, String? reason}) async {
    final sym = _symbol;
    if (sym == null || qty <= 0 || _placing) return;
    if (side == 'SELL' && qty > _positionQty) {
      _snack('You only hold $_positionQty share(s) to sell.');
      return;
    }

    setState(() => _placing = true);
    final trading = context.read<PaperTradingProvider>();
    final order = await trading.placeOrder(symbol: sym, side: side, quantity: qty, orderType: 'MARKET');
    if (!mounted) return;
    setState(() => _placing = false);

    if (order == null || !order.isExecuted) {
      _snack(trading.error ?? 'Order failed. Try again.');
      return;
    }

    final fillPrice = order.executedPrice ?? order.ltp;
    setState(() {
      _tradeCount++;
      _totalCharges += order.charges;
      if (side == 'BUY') {
        final newQty = _positionQty + qty;
        _avgPrice = newQty == 0 ? 0 : ((_avgPrice * _positionQty) + (fillPrice * qty)) / newQty;
        _positionQty = newQty;
      } else {
        _realizedPnl += (fillPrice - _avgPrice) * qty - order.charges;
        _positionQty -= qty;
        if (_positionQty <= 0) {
          _positionQty = 0;
          _avgPrice = 0;
        }
      }
    });
    unawaited(context.read<StockFeaturesProvider>().loadPaperWallet());

    if (auto) {
      _snack('Auto square-off ($reason) — sold $qty @ ${CurrencyFormatter.format(fillPrice)}');
    }
  }

  void _resetSession() {
    setState(() {
      _positionQty = 0;
      _avgPrice = 0;
      _realizedPnl = 0;
      _totalCharges = 0;
      _tradeCount = 0;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Scalping', subtitle: 'Fast one-tap paper trades'),
      body: Consumer<StockMarketProvider>(
        builder: (context, market, _) {
          final stock = _symbol == null ? null : market.getStock(_symbol!);
          final ltp = stock?.ltp ?? 0;
          final positionValue = _positionQty * ltp;
          final unrealizedPnl = _positionQty > 0 ? (ltp - _avgPrice) * _positionQty : 0.0;
          final netPnl = _realizedPnl + unrealizedPnl;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _symbolController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Symbol, e.g. RELIANCE',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _loadSymbol(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loadSymbol,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                    child: const Text('Load'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_symbol == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Enter a symbol above to start scalping.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ),
                )
              else if (_loadingQuote || stock == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _PriceHeader(symbol: _symbol!, stock: stock, colors: colors),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: TradingViewChart(
                    key: ValueKey(_symbol),
                    symbol: _symbol!,
                    intervalLabel: '1m',
                    fallbackCandles: market.getCandles(_symbol!, interval: '1m'),
                    height: 160,
                    showVolume: false,
                  ),
                ),
                const SizedBox(height: 14),
                _QtyRow(qty: _qty, onChanged: (q) => setState(() => _qty = q)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _placing ? null : () => _executeTrade('BUY', _qty),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                          child: _placing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('BUY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: (_placing || _positionQty < _qty) ? null : () => _executeTrade('SELL', _qty),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                          child: const Text('SELL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_positionQty > 0) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _placing ? null : () => _executeTrade('SELL', _positionQty),
                      icon: const Icon(Icons.flash_on_rounded, size: 18),
                      label: Text('Square off all ($_positionQty)'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _AutoSquareOffCard(
                  armed: _autoSquareOffArmed,
                  onArmedChanged: (v) => setState(() => _autoSquareOffArmed = v),
                  slController: _slController,
                  targetController: _targetController,
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _SessionScoreboard(
                  tradeCount: _tradeCount,
                  positionQty: _positionQty,
                  avgPrice: _avgPrice,
                  positionValue: positionValue,
                  realizedPnl: _realizedPnl,
                  unrealizedPnl: unrealizedPnl,
                  netPnl: netPnl,
                  totalCharges: _totalCharges,
                  onReset: _resetSession,
                  colors: colors,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  final String symbol;
  final StockModel stock;
  final AppThemeExtension colors;

  const _PriceHeader({required this.symbol, required this.stock, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isPositive = stock.changePercent >= 0;
    final changeColor = isPositive ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(stock.ltp),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: colors.textPrimary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: changeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: changeColor),
                const SizedBox(width: 4),
                Text(
                  '${stock.changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyRow extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyRow({required this.qty, required this.onChanged});

  static const _presets = [1, 5, 10, 25, 50];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Text('Qty', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$p'),
                      selected: qty == p,
                      onSelected: (_) => onChanged(p),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoSquareOffCard extends StatelessWidget {
  final bool armed;
  final ValueChanged<bool> onArmedChanged;
  final TextEditingController slController;
  final TextEditingController targetController;
  final AppThemeExtension colors;

  const _AutoSquareOffCard({
    required this.armed,
    required this.onArmedChanged,
    required this.slController,
    required this.targetController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Auto square-off', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary)),
              ),
              Switch(value: armed, onChanged: onArmedChanged),
            ],
          ),
          Text(
            'Checked every tick while open — auto-sells your position if hit.',
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: slController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Stop-loss price',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Target price',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionScoreboard extends StatelessWidget {
  final int tradeCount;
  final int positionQty;
  final double avgPrice;
  final double positionValue;
  final double realizedPnl;
  final double unrealizedPnl;
  final double netPnl;
  final double totalCharges;
  final VoidCallback onReset;
  final AppThemeExtension colors;

  const _SessionScoreboard({
    required this.tradeCount,
    required this.positionQty,
    required this.avgPrice,
    required this.positionValue,
    required this.realizedPnl,
    required this.unrealizedPnl,
    required this.netPnl,
    required this.totalCharges,
    required this.onReset,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor = netPnl >= 0 ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Session', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary))),
              TextButton(onPressed: onReset, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Trades', value: '$tradeCount', colors: colors)),
              Expanded(child: _StatTile(label: 'Open Qty', value: '$positionQty', colors: colors)),
              Expanded(
                child: _StatTile(
                  label: 'Avg Price',
                  value: positionQty > 0 ? CurrencyFormatter.format(avgPrice) : '—',
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(label: 'Realized P&L', value: CurrencyFormatter.format(realizedPnl), valueColor: realizedPnl >= 0 ? AppColors.green : AppColors.red, colors: colors),
              ),
              Expanded(
                child: _StatTile(label: 'Unrealized P&L', value: CurrencyFormatter.format(unrealizedPnl), valueColor: unrealizedPnl >= 0 ? AppColors.green : AppColors.red, colors: colors),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: pnlColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net session P&L', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textSecondary)),
                Text(
                  CurrencyFormatter.format(netPnl),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: pnlColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Charges paid this session: ${CurrencyFormatter.format(totalCharges)}', style: TextStyle(color: colors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final AppThemeExtension colors;

  const _StatTile({required this.label, required this.value, this.valueColor, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: valueColor ?? colors.textPrimary),
        ),
      ],
    );
  }
}
