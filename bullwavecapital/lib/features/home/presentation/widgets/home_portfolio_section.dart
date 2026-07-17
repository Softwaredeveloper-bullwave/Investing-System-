import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/modern_hero_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../models/portfolio_model.dart';

class HomePortfolioSection extends StatelessWidget {
  final PortfolioModel portfolio;
  final List<double> chartValues;
  final VoidCallback? onTap;

  const HomePortfolioSection({
    super.key,
    required this.portfolio,
    required this.chartValues,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final balance = portfolio.currentValue > 0
        ? portfolio.currentValue
        : portfolio.walletBalance;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernHeroCard(
            label: 'Portfolio Balance',
            amount: balance,
            changeAmount: portfolio.dayPnl,
            changePrefix: 'Today',
            chartValues: chartValues,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Invested',
                  value: CurrencyFormatter.formatCompact(
                    portfolio.totalInvestment > 0 ? portfolio.totalInvestment : 0,
                  ),
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Total P&L',
                  value: CurrencyFormatter.formatCompact(portfolio.totalProfit),
                  colors: colors,
                  valueColor: portfolio.totalProfit >= 0 ? AppColors.green : AppColors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Wallet',
                  value: CurrencyFormatter.formatCompact(portfolio.walletBalance),
                  colors: colors,
                  valueColor: AppColors.brandOrange,
                ),
              ),
            ],
          ),
          if (portfolio.monthlyProfit > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monthly plan returns',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
                  MoneyText(
                    amount: CurrencyFormatter.format(portfolio.monthlyProfit),
                    fontSize: 14,
                    color: AppColors.green,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;
  final Color? valueColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
