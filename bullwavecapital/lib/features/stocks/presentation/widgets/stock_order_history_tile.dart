import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';

class StockOrderHistoryTile extends StatelessWidget {
  final PaperTradeModel order;
  final VoidCallback? onTap;

  const StockOrderHistoryTile({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isBuy = order.isBuy;
    final sideColor = isBuy ? AppColors.green : AppColors.red;
    final pnl = order.realizedPnl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.card(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBuy ? Icons.north_east_rounded : Icons.south_west_rounded,
                    color: sideColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.symbol,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sideColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.side,
                              style: TextStyle(
                                color: sideColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.quantity} @ ${CurrencyFormatter.format(order.price)}',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        DateFormatter.displayWithTime(order.time),
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(order.totalValue),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    if (order.isSell && pnl != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${pnl >= 0 ? '+' : ''}${CurrencyFormatter.formatCompact(pnl)}',
                        style: TextStyle(
                          color: pnl >= 0 ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (order.realizedPnlPercent != null)
                        Text(
                          '${order.realizedPnlPercent! >= 0 ? '+' : ''}${order.realizedPnlPercent!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: pnl >= 0 ? AppColors.green : AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ] else if (isBuy)
                      Text(
                        'Invested',
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
