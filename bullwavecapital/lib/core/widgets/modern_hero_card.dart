import 'package:flutter/material.dart';
import '../theme/app_decorations.dart';
import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';
import '../utils/formatters.dart';
import 'money_text.dart';
import 'robinhood_line_chart.dart';

class ModernHeroCard extends StatelessWidget {
  final String label;
  final double amount;
  final double changeAmount;
  final String changePrefix;
  final List<double> chartValues;

  const ModernHeroCard({
    super.key,
    required this.label,
    required this.amount,
    required this.changeAmount,
    this.changePrefix = 'Today',
    required this.chartValues,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPositive = changeAmount >= 0;

    return Container(
      width: double.infinity,
      decoration: AppDecorations.heroCard(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                MoneyText(
                  amount: CurrencyFormatter.format(amount),
                  fontSize: 32,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isPositive ? AppColors.green : AppColors.red)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: ProfitChangeText(
                    amount: changeAmount,
                    prefix: changePrefix,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: RobinhoodLineChart(values: chartValues, height: 88),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
