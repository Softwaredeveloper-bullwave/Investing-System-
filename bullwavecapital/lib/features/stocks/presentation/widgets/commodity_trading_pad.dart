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
import '../../../../models/commodity_model.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../provider/commodity_provider.dart';
import 'commodity_order_success_sheet.dart';

class CommodityTradingPad extends StatefulWidget {
  final CommodityModel commodity;
  final String initialSide;

  const CommodityTradingPad({
    super.key,
    required this.commodity,
    this.initialSide = 'BUY',
  });

  static Future<void> show(
    BuildContext context, {
    required CommodityModel commodity,
    String initialSide = 'BUY',
  }) async {
    if (!await ensureBankVerified(context)) return;
    if (!context.mounted) return;
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => CommodityTradingPad(
        commodity: commodity,
        initialSide: initialSide.toUpperCase(),
      ),
    );
  }

  @override
  State<CommodityTradingPad> createState() => _CommodityTradingPadState();
}

class _CommodityTradingPadState extends State<CommodityTradingPad> {
  late String _side;
  late final TextEditingController _qtyController;
  bool _isPlacing = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide == 'SELL' ? 'SELL' : 'BUY';
    _qtyController = TextEditingController(text: '1');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommodityProvider>().loadDetail(widget.commodity.id);
      context.read<CommodityProvider>().loadHoldings();
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

  double _estimateInr(double usd, double rate) => usd * rate;

  Future<void> _placeOrder(CommodityModel commodity) async {
    if (_isPlacing) return;
    final provider = context.read<CommodityProvider>();
    final wallet = context.read<WalletProvider>();
    final available = provider.holdingQtyFor(commodity.id);
    final orderInr = _estimateInr(_qty * commodity.ltp, commodity.usdInrRate);

    if (_isSell && available < 1) {
      _showSnack('You don\'t hold this commodity. Switch to Buy.');
      return;
    }
    if (_isSell && _qty > available) {
      _showSnack('You can sell at most $available units.');
      return;
    }
    if (!_isSell && wallet.wallet.balance < orderInr) {
      _showSnack('Insufficient wallet balance. Add funds to continue.');
      return;
    }

    setState(() => _isPlacing = true);
    final order = await provider.placeOrder(
      commodityId: commodity.id,
      side: _side,
      quantity: _qty,
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);

    if (order == null) {
      _showSnack(provider.tradeError ?? 'Order failed. Try again.');
      return;
    }

    unawaited(wallet.loadData());
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

    return Consumer2<CommodityProvider, WalletProvider>(
      builder: (context, commodities, wallet, _) {
        final commodity = commodities.commodityById(widget.commodity.id) ?? widget.commodity;
        final holding = commodities.holdingFor(commodity.id);
        final available = commodities.holdingQtyFor(commodity.id);
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
                          Text(
                            commodity.shortName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                          Text(
                            commodity.unit,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideButton(
                        label: 'BUY',
                        selected: !_isSell,
                        color: AppColors.green,
                        onTap: () => setState(() => _side = 'BUY'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SideButton(
                        label: 'SELL',
                        selected: _isSell,
                        color: AppColors.red,
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
                              Text(
                                '\$${IndexFormatter.format(commodity.ltp)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                IndexFormatter.formatPercent(commodity.changePercent),
                                style: TextStyle(
                                  color: commodity.isPositive ? AppColors.green : AppColors.red,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(commodity.category, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (holding != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: AppDecorations.card(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your position', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(
                              '${holding.quantity} units • Avg \$${IndexFormatter.format(holding.avgPriceUsd)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Value ${CurrencyFormatter.formatDecimal(holding.currentValueInr)}',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
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
                          ActionChip(
                            label: Text('$chip'),
                            onPressed: () => _setQty(chip, available),
                          ),
                        if (_isSell && available > 1)
                          ActionChip(
                            label: const Text('Max'),
                            onPressed: () => _setQty(available, available),
                          ),
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
                            label: _isSell ? 'Est. credit (INR)' : 'Debited from wallet',
                            value: CurrencyFormatter.formatDecimal(orderInr),
                          ),
                          if (!_isSell) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Available balance',
                              value: CurrencyFormatter.format(wallet.wallet.balance),
                            ),
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
                      onPressed: (_isPlacing || (_isSell && !canSell))
                          ? null
                          : () => _placeOrder(commodity),
                      style: FilledButton.styleFrom(
                        backgroundColor: sideColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isPlacing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isSell
                                  ? 'Sell $_qty @ \$${IndexFormatter.format(commodity.ltp)}'
                                  : 'Buy $_qty @ \$${IndexFormatter.format(commodity.ltp)}',
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

  void _setQty(int qty, int maxSell) {
    final maxQty = _isSell ? (maxSell > 0 ? maxSell : 1) : 99999;
    final clamped = qty.clamp(1, maxQty);
    _qtyController.text = '$clamped';
    setState(() {});
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
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.appColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
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
        Text(
          value,
          style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 16 : 14),
        ),
      ],
    );
  }
}
