import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import 'trade_order_sheets.dart';

/// Dhan-style order pad — Buy/Sell toggle, live price, position & order summary.
class StockTradingPad extends StatefulWidget {
  final StockModel stock;
  final String initialSide;

  const StockTradingPad({
    super.key,
    required this.stock,
    this.initialSide = 'BUY',
  });

  static Future<void> show(
    BuildContext context, {
    required StockModel stock,
    String initialSide = 'BUY',
  }) async {
    if (!await ensureBankVerified(context)) return;
    if (!context.mounted) return;
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => StockTradingPad(
        stock: stock,
        initialSide: initialSide.toUpperCase(),
      ),
    );
  }

  @override
  State<StockTradingPad> createState() => _StockTradingPadState();
}

class _StockTradingPadState extends State<StockTradingPad> {
  late String _side;
  late final TextEditingController _qtyController;
  bool _isPlacing = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide == 'SELL' ? 'SELL' : 'BUY';
    _qtyController = TextEditingController(text: '1');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMarketProvider>().ensureStock(widget.stock.symbol);
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false);
      context.read<WalletProvider>().loadData();
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

  int _availableQty(StockPortfolioProvider portfolio) =>
      portfolio.holdingQtyFor(widget.stock.symbol);

  StockHoldingModel? _holding(StockPortfolioProvider portfolio) =>
      portfolio.holdingFor(widget.stock.symbol);

  void _setSide(String side) {
    if (_side == side) return;
    setState(() => _side = side);
    final maxQty = _availableQty(context.read<StockPortfolioProvider>());
    if (side == 'SELL' && maxQty > 0 && _qty > maxQty) {
      _qtyController.text = '$maxQty';
    }
  }

  void _setQty(int qty) {
    final portfolio = context.read<StockPortfolioProvider>();
    final maxQty = _isSell ? _availableQty(portfolio) : 99999;
    final clamped = qty.clamp(1, maxQty > 0 ? maxQty : 1);
    _qtyController.text = '$clamped';
    setState(() {});
  }

  void _adjustQty(int delta) => _setQty(_qty + delta);

  Future<void> _placeOrder(StockModel stock) async {
    if (_isPlacing) return;
    final portfolio = context.read<StockPortfolioProvider>();
    final available = _availableQty(portfolio);

    if (_isSell && available < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You don\'t hold this stock. Switch to Buy.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSell && _qty > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can sell at most $available shares.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);
    final features = context.read<StockFeaturesProvider>();
    final order = await features.placePaperTrade(
      symbol: stock.symbol,
      side: _side,
      qty: _qty,
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(features.tradeError ?? 'Order failed. Try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    portfolio.applyExecutedOrder(order);
    unawaited(portfolio.loadPortfolio(refreshQuotes: false));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await OrderSuccessSheet.show(context, order);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenH = MediaQuery.sizeOf(context).height;

    return Consumer3<StockMarketProvider, StockPortfolioProvider, WalletProvider>(
      builder: (context, market, portfolio, wallet, _) {
        final stock = market.getStock(widget.stock.symbol) ?? widget.stock;
        final isPositive = stock.isPositive;
        final changeColor = isPositive ? AppColors.green : AppColors.red;
        final holding = _holding(portfolio);
        final available = _availableQty(portfolio);
        final orderValue = _qty * stock.ltp;
        final canSell = available >= 1;
        final sideColor = _isSell ? AppColors.red : AppColors.green;

        double? estRealizedPnl;
        if (_isSell && holding != null) {
          estRealizedPnl = (stock.ltp - holding.avgPrice) * _qty;
        }

        return Container(
          height: screenH * 0.92,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _PadHeader(
                stock: stock,
                onClose: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
              _BuySellToggle(
                side: _side,
                canSell: canSell,
                onChanged: _setSide,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [
                    _LivePriceCard(
                      stock: stock,
                      changeColor: changeColor,
                      isPositive: isPositive,
                    ),
                    const SizedBox(height: 14),
                    _OhlcRow(stock: stock),
                    if (holding != null) ...[
                      const SizedBox(height: 14),
                      _HoldingSummary(holding: holding),
                    ],
                    const SizedBox(height: 18),
                    _SectionLabel('Order type'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: const Text(
                          'MARKET',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Quantity'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QtyStepButton(icon: Icons.remove, onTap: () => _adjustQty(-1)),
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colors.border),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        _QtyStepButton(icon: Icons.add, onTap: () => _adjustQty(1)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final chip in [1, 5, 10, 25, 50])
                          _QtyChip(label: '$chip', onTap: () => _setQty(chip)),
                        if (_isSell && available > 1)
                          _QtyChip(label: 'Max', onTap: () => _setQty(available)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _OrderSummaryCard(
                      isSell: _isSell,
                      orderValue: orderValue,
                      walletBalance: wallet.wallet.balance,
                      avgPrice: holding?.avgPrice,
                      estRealizedPnl: estRealizedPnl,
                      availableQty: available,
                    ),
                  ],
                ),
              ),
              _ConfirmBar(
                isSell: _isSell,
                isPlacing: _isPlacing,
                qty: _qty,
                ltp: stock.ltp,
                sideColor: sideColor,
                enabled: !_isSell || canSell,
                onConfirm: () => _placeOrder(stock),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PadHeader extends StatelessWidget {
  final StockModel stock;
  final VoidCallback onClose;

  const _PadHeader({required this.stock, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stock.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stock.exchange,
                        style: TextStyle(fontSize: 10, color: colors.textMuted, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Text(
                  stock.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BuySellToggle extends StatelessWidget {
  final String side;
  final bool canSell;
  final ValueChanged<String> onChanged;

  const _BuySellToggle({
    required this.side,
    required this.canSell,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ToggleTab(
                label: 'Buy',
                selected: side == 'BUY',
                color: AppColors.green,
                onTap: () => onChanged('BUY'),
              ),
            ),
            Expanded(
              child: _ToggleTab(
                label: canSell ? 'Sell' : 'Sell',
                selected: side == 'SELL',
                color: AppColors.red,
                onTap: () => onChanged('SELL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: selected ? Colors.white : context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LivePriceCard extends StatelessWidget {
  final StockModel stock;
  final Color changeColor;
  final bool isPositive;

  const _LivePriceCard({
    required this.stock,
    required this.changeColor,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Price', style: TextStyle(color: context.appColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(stock.ltp),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                      color: changeColor,
                      size: 22,
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${CurrencyFormatter.format(stock.change)} (${stock.changePercent.toStringAsFixed(2)}%)',
                      style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OhlcRow extends StatelessWidget {
  final StockModel stock;

  const _OhlcRow({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OhlcCell(label: 'Open', value: CurrencyFormatter.format(stock.open)),
        _OhlcCell(label: 'High', value: CurrencyFormatter.format(stock.high)),
        _OhlcCell(label: 'Low', value: CurrencyFormatter.format(stock.low)),
        _OhlcCell(label: 'Prev', value: CurrencyFormatter.format(stock.previousClose)),
      ],
    );
  }
}

class _OhlcCell extends StatelessWidget {
  final String label;
  final String value;

  const _OhlcCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _HoldingSummary extends StatelessWidget {
  final StockHoldingModel holding;

  const _HoldingSummary({required this.holding});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnlColor = holding.isPositive ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, size: 16, color: AppColors.brandOrange),
              const SizedBox(width: 6),
              Text(
                'Your Holdings',
                style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(label: 'Qty', value: '${holding.quantity}'),
              _MiniStat(label: 'Avg', value: CurrencyFormatter.format(holding.avgPrice)),
              _MiniStat(label: 'Value', value: CurrencyFormatter.formatCompact(holding.currentValue)),
              _MiniStat(
                label: 'P&L',
                value: '${holding.pnl >= 0 ? '+' : ''}${CurrencyFormatter.formatCompact(holding.pnl)}',
                valueColor: pnlColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.appColors.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 13,
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

class _QtyChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QtyChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onPressed: onTap,
      backgroundColor: context.appColors.surfaceSecondary,
      side: BorderSide(color: context.appColors.border),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final bool isSell;
  final double orderValue;
  final double walletBalance;
  final double? avgPrice;
  final double? estRealizedPnl;
  final int availableQty;

  const _OrderSummaryCard({
    required this.isSell,
    required this.orderValue,
    required this.walletBalance,
    this.avgPrice,
    this.estRealizedPnl,
    required this.availableQty,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnl = estRealizedPnl;
    final pnlColor = (pnl ?? 0) >= 0 ? AppColors.green : AppColors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          _SummaryRow(
            label: isSell ? 'Estimated credit' : 'Order value',
            value: CurrencyFormatter.format(orderValue),
            bold: true,
          ),
          if (!isSell) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Available balance',
              value: CurrencyFormatter.format(walletBalance),
            ),
          ],
          if (isSell) ...[
            const SizedBox(height: 8),
            _SummaryRow(label: 'Available to sell', value: '$availableQty shares'),
            if (avgPrice != null) ...[
              const SizedBox(height: 8),
              _SummaryRow(label: 'Avg buy price', value: CurrencyFormatter.format(avgPrice!)),
            ],
            if (pnl != null) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Est. realized P&L', style: TextStyle(color: colors.textSecondary)),
                  Text(
                    '${pnl >= 0 ? '+' : ''}${CurrencyFormatter.format(pnl)}',
                    style: TextStyle(color: pnlColor, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ],
          ],
        ],
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
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final bool isSell;
  final bool isPlacing;
  final int qty;
  final double ltp;
  final Color sideColor;
  final bool enabled;
  final VoidCallback onConfirm;

  const _ConfirmBar({
    required this.isSell,
    required this.isPlacing,
    required this.qty,
    required this.ltp,
    required this.sideColor,
    required this.enabled,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final action = isSell ? 'Sell' : 'Buy';
    final priceStr = CurrencyFormatter.format(ltp);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSell && !enabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'No shares to sell. Buy first or switch to Buy.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: enabled && !isPlacing ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: sideColor,
                  disabledBackgroundColor: sideColor.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isPlacing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        enabled
                            ? '$action $qty @ $priceStr'
                            : '$action unavailable',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
