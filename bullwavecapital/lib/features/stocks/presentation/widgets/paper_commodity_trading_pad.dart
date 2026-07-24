import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/commodity_model.dart';
import '../provider/commodity_provider.dart';
import '../provider/paper_trading_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../widgets/commodity_order_success_sheet.dart';
import '../widgets/simulation_badge.dart';

/// Simulated-money twin of [CommodityTradingPad] — reads live commodity
/// quotes from the existing [CommodityProvider] (same market data as real
/// trading) but places orders through
/// [PaperTradingProvider.placeCommodityOrder] against the paper wallet.
class PaperCommodityTradingPad extends StatefulWidget {
  final CommodityModel commodity;
  final String initialSide;

  const PaperCommodityTradingPad({
    super.key,
    required this.commodity,
    this.initialSide = 'BUY',
  });

  static Future<void> show(
    BuildContext context, {
    required CommodityModel commodity,
    String initialSide = 'BUY',
  }) {
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => PaperCommodityTradingPad(
        commodity: commodity,
        initialSide: initialSide.toUpperCase(),
      ),
    );
  }

  @override
  State<PaperCommodityTradingPad> createState() => _PaperCommodityTradingPadState();
}

class _PaperCommodityTradingPadState extends State<PaperCommodityTradingPad> {
  late String _side;
  late final TextEditingController _qtyController;
  bool _isPlacing = false;
  bool _chartLoading = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide == 'SELL' ? 'SELL' : 'BUY';
    _qtyController = TextEditingController(text: '1');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CommodityProvider>().loadDetail(widget.commodity.id);
      context.read<PaperTradingProvider>().loadCommodityOrders();
      context.read<StockFeaturesProvider>().loadPaperWallet();
      setState(() => _chartLoading = true);
      await context.read<StockMarketProvider>().loadCandles(widget.commodity.id, interval: '1d');
      if (mounted) setState(() => _chartLoading = false);
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  bool get _isSell => _side == 'SELL';

  int get _qty {
    final parsed = int.tryParse(_qtyController.text.trim());
    return parsed == null || parsed < 1 ? 1 : parsed;
  }

  double _estimateInr(double usd, double rate) => usd * rate;

  int _availableUnits(PaperTradingProvider trading) {
    for (final h in trading.commodityHoldings) {
      if (h.commodityId == widget.commodity.id) return h.quantity;
    }
    return 0;
  }

  void _setQty(int qty, int maxSell) {
    final maxQty = _isSell ? (maxSell > 0 ? maxSell : 1) : 99999;
    final clamped = qty.clamp(1, maxQty);
    _qtyController.text = '$clamped';
    setState(() {});
  }

  Future<void> _placeOrder(CommodityModel commodity) async {
    if (_isPlacing) return;
    final trading = context.read<PaperTradingProvider>();
    final features = context.read<StockFeaturesProvider>();
    final available = _availableUnits(trading);
    final orderInr = _estimateInr(_qty * commodity.ltp, commodity.usdInrRate);

    if (_isSell && available < 1) {
      _showSnack('You don\'t hold this commodity in your paper account. Switch to Buy.');
      return;
    }
    if (_isSell && _qty > available) {
      _showSnack('You can sell at most $available units.');
      return;
    }
    if (!_isSell && (features.virtualBalance ?? 0) < orderInr) {
      _showSnack('Insufficient virtual balance.');
      return;
    }

    setState(() => _isPlacing = true);
    final order = await trading.placeCommodityOrder(
      commodityId: commodity.id,
      side: _side,
      quantity: _qty,
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);

    if (order == null) {
      _showSnack(trading.error ?? 'Paper order failed. Try again.');
      return;
    }

    unawaited(features.loadPaperWallet());
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await CommodityOrderSuccessSheet.show(context, order);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenH = MediaQuery.sizeOf(context).height;

    return Consumer4<CommodityProvider, PaperTradingProvider, StockFeaturesProvider, StockMarketProvider>(
      builder: (context, commodities, trading, features, market, _) {
        final commodity = commodities.commodityById(widget.commodity.id) ?? widget.commodity;
        final available = _availableUnits(trading);
        final canSell = available >= 1;
        final sideColor = _isSell ? AppColors.red : AppColors.green;
        final orderUsd = _qty * commodity.ltp;
        final orderInr = _estimateInr(orderUsd, commodity.usdInrRate);

        return Container(
          height: screenH * 0.88,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(commodity.shortName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text(commodity.unit, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: SimulationOnlyBadge(compact: true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideButton(
                        label: 'BUY', selected: !_isSell, color: AppColors.green,
                        onTap: () => setState(() => _side = 'BUY'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SideButton(
                        label: 'SELL', selected: _isSell, color: AppColors.red,
                        enabled: canSell,
                        onTap: canSell ? () => setState(() => _side = 'SELL') : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppDecorations.card(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Live price', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('\$${IndexFormatter.format(commodity.ltp)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                IndexFormatter.formatPercent(commodity.changePercent),
                                style: TextStyle(color: commodity.isPositive ? AppColors.green : AppColors.red, fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              Text(commodity.category, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: TradingViewChart(
                        key: ValueKey(commodity.id),
                        symbol: commodity.id,
                        intervalLabel: '1D',
                        isCommodity: true,
                        fallbackCandles: market.getCandles(commodity.id, interval: '1d'),
                        isLoading: _chartLoading,
                        height: 150,
                      ),
                    ),
                    if (available > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: AppDecorations.card(context),
                        child: Text('Your paper position: $available units', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text('Quantity (units)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QtyStepButton(icon: Icons.remove, onTap: () => _setQty(_qty - 1, available)),
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        _QtyStepButton(icon: Icons.add, onTap: () => _setQty(_qty + 1, available)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final chip in [1, 2, 5, 10])
                          ActionChip(label: Text('$chip'), onPressed: () => _setQty(chip, available)),
                        if (_isSell && available > 1)
                          ActionChip(label: const Text('Max'), onPressed: () => _setQty(available, available)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppDecorations.card(context),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: _isSell ? 'Est. credit' : 'Order value (USD)',
                            value: '\$${IndexFormatter.format(orderUsd)}',
                            bold: true,
                          ),
                          const SizedBox(height: 8),
                          _SummaryRow(
                            label: _isSell ? 'Est. credit (INR)' : 'Debited from paper wallet',
                            value: CurrencyFormatter.formatDecimal(orderInr),
                          ),
                          if (!_isSell) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(label: 'Virtual balance', value: CurrencyFormatter.format(features.virtualBalance ?? 0)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: (_isPlacing || (_isSell && !canSell)) ? null : () => _placeOrder(commodity),
                      style: FilledButton.styleFrom(
                        backgroundColor: sideColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isPlacing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isSell
                                  ? 'Paper Sell $_qty @ \$${IndexFormatter.format(commodity.ltp)}'
                                  : 'Paper Buy $_qty @ \$${IndexFormatter.format(commodity.ltp)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? color : context.appColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(color: selected ? Colors.white : context.appColors.textPrimary, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _QtyStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: context.appColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 22)),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 16 : 14)),
      ],
    );
  }
}
