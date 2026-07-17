import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/commodity_model.dart';

class CommodityOrderSuccessSheet extends StatelessWidget {
  final CommodityTradeModel order;

  const CommodityOrderSuccessSheet({super.key, required this.order});

  static Future<void> show(BuildContext context, CommodityTradeModel order) {
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => CommodityOrderSuccessSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSell = order.isSell;
    final pnl = order.realizedPnlInr;
    final isProfit = (pnl ?? 0) >= 0;
    final accent = isSell ? (isProfit ? AppColors.green : AppColors.red) : AppColors.green;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
              Text(order.name, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
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
                    _Row(label: 'Commodity', value: order.shortName),
                    _Row(label: 'Order Type', value: 'MARKET ${order.side}'),
                    _Row(label: 'Quantity', value: '${order.quantity} units'),
                    _Row(label: 'Price (USD)', value: '\$${IndexFormatter.format(order.priceUsd)}'),
                    _Row(
                      label: isSell ? 'Credited to wallet' : 'Debited from wallet',
                      value: CurrencyFormatter.formatDecimal(order.amountInr),
                      bold: true,
                    ),
                    if (isSell && pnl != null) ...[
                      const Divider(height: 24),
                      Text('Realized P&L', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${pnl >= 0 ? '+' : ''}${CurrencyFormatter.formatDecimal(pnl)}',
                        style: TextStyle(
                          color: isProfit ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                    ],
                    if (order.holdingQty != null) ...[
                      const Divider(height: 24),
                      _Row(label: 'Units held', value: '${order.holdingQty}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Row({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 16 : 14),
          ),
        ],
      ),
    );
  }
}
