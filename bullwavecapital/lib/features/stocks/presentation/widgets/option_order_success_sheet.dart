import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/option_trade_model.dart';

class OptionOrderSuccessSheet extends StatelessWidget {
  final OptionTradeModel order;
  final String currencySymbol;

  const OptionOrderSuccessSheet({
    super.key,
    required this.order,
    this.currencySymbol = '₹',
  });

  static Future<void> show(
    BuildContext context,
    OptionTradeModel order, {
    String currencySymbol = '₹',
  }) {
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => OptionOrderSuccessSheet(order: order, currencySymbol: currencySymbol),
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
              Text(order.contractLabel, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
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
                    _Row(label: 'Order Type', value: 'MARKET ${order.side}'),
                    _Row(label: 'Lots', value: '${order.quantity}'),
                    _Row(
                      label: 'Premium',
                      value: '$currencySymbol${order.premium.toStringAsFixed(2)}',
                    ),
                    _Row(
                      label: isSell ? 'Credited to wallet' : 'Debited from wallet',
                      value: CurrencyFormatter.formatDecimal(order.amountInr),
                      bold: true,
                    ),
                    if (isSell && pnl != null) ...[
                      const SizedBox(height: 8),
                      _Row(
                        label: 'Realized P&L',
                        value: CurrencyFormatter.formatDecimal(pnl),
                        valueColor: isProfit ? AppColors.green : AppColors.red,
                        bold: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Done'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
