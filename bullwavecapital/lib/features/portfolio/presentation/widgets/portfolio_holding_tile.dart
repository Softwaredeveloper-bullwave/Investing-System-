import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/modern_icon_badge.dart';
import '../../../../models/stock_model.dart';

class PortfolioHoldingTile extends StatelessWidget {
  final StockHoldingModel holding;
  final VoidCallback? onTap;
  final VoidCallback? onBuy;
  final VoidCallback? onSell;

  const PortfolioHoldingTile({
    super.key,
    required this.holding,
    this.onTap,
    this.onBuy,
    this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnlColor = holding.isPositive ? AppColors.green : AppColors.red;
    final dayColor = holding.isDayPositive ? AppColors.green : AppColors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.gradientTintCard(context, tint: pnlColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModernStockAvatar(symbol: holding.symbol, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holding.symbol,
                            style: ThemeAType.cardTitle(size: 16, color: colors.textPrimary),
                          ),
                          Text(
                            holding.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThemeAType.secondary(size: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(holding.currentValue),
                          style: ThemeAType.price(size: 16, color: colors.textPrimary),
                        ),
                        Text(
                          '${holding.pnl >= 0 ? '+' : ''}${CurrencyFormatter.formatCompact(holding.pnl)} (${holding.pnlPercent.toStringAsFixed(2)}%)',
                          style: ThemeAType.label(size: 12, color: pnlColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _Metric(label: 'Qty', value: '${holding.quantity}'),
                      _Metric(label: 'Avg', value: CurrencyFormatter.format(holding.avgPrice)),
                      _Metric(label: 'LTP', value: CurrencyFormatter.format(holding.ltp)),
                      _Metric(
                        label: 'Today',
                        value: '${holding.dayPnl >= 0 ? '+' : ''}${CurrencyFormatter.formatCompact(holding.dayPnl)}',
                        valueColor: dayColor,
                      ),
                    ],
                  ),
                ),
                if (onBuy != null || onSell != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onBuy != null)
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: FilledButton(
                              onPressed: onBuy,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                'Buy',
                                style: ThemeAType.label(size: 14, color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                      if (onBuy != null && onSell != null) const SizedBox(width: 10),
                      if (onSell != null)
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: onSell,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brandPink,
                                side: BorderSide(
                                  color: AppColors.brandPink.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                'Sell',
                                style: ThemeAType.label(size: 14, color: AppColors.brandPink),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ThemeAType.muted(size: 10, color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: ThemeAType.label(
              size: 12,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
