import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_portfolio_provider.dart';

/// Fintech-style order success sheet — shows P&L on sell, holding summary on buy.
class OrderSuccessSheet extends StatelessWidget {
  final PaperTradeModel order;

  const OrderSuccessSheet({super.key, required this.order});

  static Future<void> show(BuildContext context, PaperTradeModel order) {
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => OrderSuccessSheet(order: order),
    );
  }

  void _openPortfolio(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      AppNavigation.goTab(context, AppRoutes.portfolio);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSell = order.isSell;
    final pnl = order.realizedPnl;
    final pnlPct = order.realizedPnlPercent;
    final isProfit = (pnl ?? 0) >= 0;
    final accent = isSell ? (isProfit ? AppColors.green : AppColors.red) : AppColors.green;

    return Consumer<StockPortfolioProvider>(
      builder: (context, portfolio, _) {
        final summary = portfolio.summary;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSell ? Icons.sell_rounded : Icons.shopping_bag_rounded,
                  color: accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSell ? 'Sell Order Executed' : 'Buy Order Executed',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                order.stockName.isNotEmpty ? order.stockName : order.symbol,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    _Row(label: 'Symbol', value: order.symbol),
                    _Row(label: 'Order Type', value: 'MARKET ${order.side}'),
                    _Row(label: 'Quantity', value: '${order.quantity} shares'),
                    _Row(label: 'Price', value: CurrencyFormatter.format(order.price)),
                    _Row(
                      label: isSell ? 'Sell Value' : 'Invested',
                      value: CurrencyFormatter.format(order.totalValue),
                      bold: true,
                    ),
                    if (isSell && order.avgCost != null) ...[
                      const Divider(height: 24),
                      _Row(label: 'Avg Buy Price', value: CurrencyFormatter.format(order.avgCost!)),
                    ],
                    if (isSell && pnl != null) ...[
                      const SizedBox(height: 12),
                      Text('Realized P&L', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${pnl >= 0 ? '+' : ''}${CurrencyFormatter.format(pnl)}',
                        style: TextStyle(
                          color: isProfit ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                        ),
                      ),
                      if (pnlPct != null)
                        Text(
                          '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isProfit ? AppColors.green : AppColors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                    ],
                    if (isSell && pnl != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        isProfit ? 'You made a profit on this sale' : 'You booked a loss on this sale',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                    ],
                    if (!isSell && order.holdingQty != null) ...[
                      const Divider(height: 24),
                      _Row(label: 'Holdings', value: '${order.holdingQty} shares'),
                      if (order.holdingAvgPrice != null)
                        _Row(
                          label: 'New Avg Price',
                          value: CurrencyFormatter.format(order.holdingAvgPrice!),
                        ),
                      if (order.unrealizedPnl != null)
                        _Row(
                          label: 'Unrealized P&L',
                          value:
                              '${order.unrealizedPnl! >= 0 ? '+' : ''}${CurrencyFormatter.format(order.unrealizedPnl!)}',
                          valueColor: order.unrealizedPnl! >= 0 ? AppColors.green : AppColors.red,
                        ),
                    ],
                  ],
                ),
              ),
              if (portfolio.holdingsCount > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio updated',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Holdings', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                          Text(
                            '${portfolio.holdingsCount} stocks',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Portfolio value', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                          Text(
                            CurrencyFormatter.format(summary.currentValue),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total P&L', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                          Text(
                            '${summary.totalPnl >= 0 ? '+' : ''}${CurrencyFormatter.format(summary.totalPnl)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: summary.totalPnl >= 0 ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openPortfolio(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Portfolio', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontSize: bold ? 15 : 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to place a market buy/sell order.
class TradeOrderSheet extends StatefulWidget {
  final StockModel stock;
  final String side;
  final int availableQty;

  const TradeOrderSheet({
    super.key,
    required this.stock,
    required this.side,
    this.availableQty = 0,
  });

  static Future<int?> show(
    BuildContext context, {
    required StockModel stock,
    required String side,
    int availableQty = 0,
  }) {
    return AppNavigation.showAppBottomSheet<int>(
      context,
      builder: (_) => TradeOrderSheet(
        stock: stock,
        side: side.toUpperCase(),
        availableQty: availableQty,
      ),
    );
  }

  @override
  State<TradeOrderSheet> createState() => _TradeOrderSheetState();
}

class _TradeOrderSheetState extends State<TradeOrderSheet> {
  int _qty = 1;

  bool get _isSell => widget.side == 'SELL';
  double get _estimatedTotal => _qty * widget.stock.ltp;

  @override
  void initState() {
    super.initState();
    if (_isSell && widget.availableQty > 0) {
      _qty = 1;
    }
  }

  void _adjustQty(int delta) {
    final next = _qty + delta;
    if (next < 1) return;
    if (_isSell && next > widget.availableQty) return;
    setState(() => _qty = next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sideColor = _isSell ? AppColors.red : AppColors.green;
    final canSell = !_isSell || widget.availableQty >= 1;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.side,
                        style: TextStyle(color: sideColor, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.stock.symbol,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          Text(
                            widget.stock.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('LTP', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                        Text(
                          CurrencyFormatter.format(widget.stock.ltp),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isSell) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.availableQty > 0
                        ? 'Available: ${widget.availableQty} shares'
                        : 'No shares available to sell',
                    style: TextStyle(
                      color: widget.availableQty > 0 ? colors.textSecondary : AppColors.red,
                      fontSize: 13,
                      fontWeight: widget.availableQty > 0 ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Quantity', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove, onTap: () => _adjustQty(-1)),
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_qty',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add, onTap: () => _adjustQty(1)),
                    if (_isSell && widget.availableQty > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TextButton(
                          onPressed: () => setState(() => _qty = widget.availableQty),
                          child: const Text('Max'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.card(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSell ? 'Estimated credit' : 'Estimated cost',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      Text(
                        CurrencyFormatter.format(_estimatedTotal),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: canSell ? () => Navigator.of(context, rootNavigator: true).pop(_qty) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: sideColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isSell ? 'Sell $_qty shares' : 'Buy $_qty shares',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

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
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}
