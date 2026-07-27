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
import '../provider/paper_trading_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import 'trade_order_sheets.dart';

const List<String> _orderTypes = ['MARKET', 'LIMIT', 'SL-M', 'SL'];

String _orderTypeLabel(String type) {
  switch (type) {
    case 'LIMIT':
      return 'Limit';
    case 'SL-M':
      return 'SL-M';
    case 'SL':
      return 'SL';
    default:
      return 'Market';
  }
}

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
  late final TextEditingController _limitPriceController;
  late final TextEditingController _triggerPriceController;
  String _orderType = 'MARKET';
  bool _isPlacing = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide == 'SELL' ? 'SELL' : 'BUY';
    _qtyController = TextEditingController(text: '1');
    _limitPriceController = TextEditingController();
    _triggerPriceController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMarketProvider>().ensureStock(widget.stock.symbol);
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false);
      context.read<StockFeaturesProvider>().loadPaperWallet();
      _limitPriceController.text = widget.stock.ltp.toStringAsFixed(2);
      _triggerPriceController.text = widget.stock.ltp.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _limitPriceController.dispose();
    _triggerPriceController.dispose();
    super.dispose();
  }

  bool get _isMarket => _orderType == 'MARKET';
  bool get _needsLimitPrice => _orderType == 'LIMIT' || _orderType == 'SL';
  bool get _needsTriggerPrice => _orderType == 'SL-M' || _orderType == 'SL';

  double? get _limitPrice => double.tryParse(_limitPriceController.text.trim());
  double? get _triggerPrice => double.tryParse(_triggerPriceController.text.trim());

  void _setOrderType(String type) {
    if (_orderType == type) return;
    setState(() => _orderType = type);
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

    if (_needsLimitPrice && (_limitPrice == null || _limitPrice! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid limit price.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_needsTriggerPrice && (_triggerPrice == null || _triggerPrice! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid trigger (stop) price.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isMarket) {
      await _placeNonMarketOrder(stock);
      return;
    }

    final features = context.read<StockFeaturesProvider>();
    final virtualBalance = features.virtualBalance;
    final orderCost = _qty * stock.ltp;
    if (!_isSell && virtualBalance != null && orderCost > virtualBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough virtual balance. This order needs '
            '${CurrencyFormatter.format(orderCost)} but you have '
            '${CurrencyFormatter.format(virtualBalance)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);
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

  /// LIMIT / SL-M / SL — goes through the paper-trading order book instead
  /// of the legacy immediate-fill endpoint, since these may sit PENDING
  /// rather than executing right away.
  Future<void> _placeNonMarketOrder(StockModel stock) async {
    final paperTrading = context.read<PaperTradingProvider>();
    setState(() => _isPlacing = true);
    final order = await paperTrading.placeOrder(
      symbol: stock.symbol,
      side: _side,
      quantity: _qty,
      orderType: _orderType,
      limitPrice: _needsLimitPrice ? _limitPrice : null,
      triggerPrice: _needsTriggerPrice ? _triggerPrice : null,
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paperTrading.error ?? 'Order failed. Try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    unawaited(context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          order.isExecuted
              ? '${order.isBuy ? 'Buy' : 'Sell'} ${order.quantity} ${order.symbol} executed @ '
                  '${CurrencyFormatter.format(order.executedPrice ?? 0)}'
              : '${_orderTypeLabel(order.orderType)} order placed — pending, will fill when the '
                  'price condition is met.',
        ),
        backgroundColor: order.isExecuted ? AppColors.green : AppColors.brandOrange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenH = MediaQuery.sizeOf(context).height;

    return Consumer3<StockMarketProvider, StockPortfolioProvider, StockFeaturesProvider>(
      builder: (context, market, portfolio, features, _) {
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in _orderTypes)
                          _OrderTypeChip(
                            label: _orderTypeLabel(type),
                            selected: _orderType == type,
                            onTap: () => _setOrderType(type),
                          ),
                      ],
                    ),
                    if (_needsLimitPrice || _needsTriggerPrice) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (_needsTriggerPrice)
                            Expanded(
                              child: _PriceInputField(
                                label: 'Trigger price',
                                controller: _triggerPriceController,
                              ),
                            ),
                          if (_needsTriggerPrice && _needsLimitPrice) const SizedBox(width: 12),
                          if (_needsLimitPrice)
                            Expanded(
                              child: _PriceInputField(
                                label: 'Limit price',
                                controller: _limitPriceController,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _orderType == 'LIMIT'
                            ? 'Fills only at your limit price or better.'
                            : _orderType == 'SL-M'
                                ? 'Turns into a market order once the trigger price is hit.'
                                : 'Turns into a limit order once the trigger price is hit.',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
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
                      virtualBalance: features.virtualBalance ?? 0,
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
                isMarket: _isMarket,
                orderTypeLabel: _orderTypeLabel(_orderType),
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRACTICE',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.brandOrange,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
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

class _OrderTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderTypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandOrange.withValues(alpha: 0.14) : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.brandOrange : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            fontSize: 13,
            color: selected ? AppColors.brandOrange : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PriceInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _PriceInputField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final bool isSell;
  final double orderValue;
  final double virtualBalance;
  final double? avgPrice;
  final double? estRealizedPnl;
  final int availableQty;

  const _OrderSummaryCard({
    required this.isSell,
    required this.orderValue,
    required this.virtualBalance,
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
              label: 'Virtual balance',
              value: CurrencyFormatter.format(virtualBalance),
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
  final bool isMarket;
  final String orderTypeLabel;

  const _ConfirmBar({
    required this.isSell,
    required this.isPlacing,
    required this.qty,
    required this.ltp,
    required this.sideColor,
    required this.enabled,
    required this.onConfirm,
    this.isMarket = true,
    this.orderTypeLabel = 'Market',
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
                        !enabled
                            ? '$action unavailable'
                            : isMarket
                                ? '$action $qty @ $priceStr'
                                : 'Place $orderTypeLabel $action Order',
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
