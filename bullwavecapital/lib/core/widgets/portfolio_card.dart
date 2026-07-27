import 'package:flutter/material.dart';
import '../theme/theme_a.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/app_theme_extension.dart';
import '../constants/dimensions.dart';
import '../utils/formatters.dart';
import 'premium_ui_kit.dart';
import 'robinhood_card.dart';
import 'money_text.dart';
import 'scale_tap.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final double totalInvestment;
  final double currentValue;
  final double totalProfit;
  final double todayPnl;
  final double? todayPnlPercent;

  const PortfolioSummaryCard({
    super.key,
    required this.totalInvestment,
    required this.currentValue,
    required this.totalProfit,
    required this.todayPnl,
    this.todayPnlPercent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Portfolio Value', style: AppTypography.moneyLabel(colors)),
                    const SizedBox(height: 6),
                    MoneyText(amount: CurrencyFormatter.format(currentValue), fontSize: 38),
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryLight,
                ),
                child: Icon(Icons.donut_large_rounded, color: colors.primary, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProfitChangeText(amount: todayPnl, prefix: 'Today'),
          if (todayPnlPercent != null) ...[
            const SizedBox(height: 4),
            Text(
              '${todayPnlPercent! >= 0 ? '+' : ''}${todayPnlPercent!.toStringAsFixed(2)}% today',
              style: AppTypography.profitChange(isPositive: todayPnl >= 0),
            ),
          ],
          const SizedBox(height: AppDimensions.paddingLg),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Invested',
                  value: CurrencyFormatter.formatCompact(totalInvestment),
                  colors: colors,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Total P&L',
                  value: CurrencyFormatter.formatCompact(totalProfit),
                  colors: colors,
                  green: totalProfit >= 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;
  final bool green;

  const _StatItem({
    required this.label,
    required this.value,
    required this.colors,
    this.green = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.moneyLabel(colors)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.balance(
            colors,
            color: green ? colors.positive : colors.textPrimary,
          ).copyWith(fontSize: 16),
        ),
      ],
    );
  }
}

class InvestmentCard extends StatelessWidget {
  final String name;
  final double minimumInvestment;
  final double annualReturn;
  final double? monthlyReturnMin;
  final double? monthlyReturnMax;
  final String risk;
  final VoidCallback? onTap;
  final bool compact;

  const InvestmentCard({
    super.key,
    required this.name,
    required this.minimumInvestment,
    required this.annualReturn,
    this.monthlyReturnMin,
    this.monthlyReturnMax,
    this.risk = 'Medium',
    this.onTap,
    this.compact = false,
  });

  String get _returnBadge {
    if (monthlyReturnMin != null &&
        monthlyReturnMax != null &&
        monthlyReturnMax! > monthlyReturnMin!) {
      return '${monthlyReturnMin!.toStringAsFixed(2)}–${monthlyReturnMax!.toStringAsFixed(2)}%';
    }
    if (monthlyReturnMin != null && monthlyReturnMin! > 0) {
      return '${monthlyReturnMin!.toStringAsFixed(2)}%';
    }
    return '${annualReturn.toStringAsFixed(1)}%';
  }

  String get _returnDetail {
    if (monthlyReturnMin != null &&
        monthlyReturnMax != null &&
        monthlyReturnMax! > monthlyReturnMin!) {
      return '${monthlyReturnMin!.toStringAsFixed(2)}–${monthlyReturnMax!.toStringAsFixed(2)}% monthly';
    }
    if (monthlyReturnMin != null && monthlyReturnMin! > 0) {
      return '${monthlyReturnMin!.toStringAsFixed(2)}% monthly';
    }
    return '${annualReturn.toStringAsFixed(1)}% p.a.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return RobinhoodCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 14 : AppDimensions.paddingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _returnBadge,
                  style: TextStyle(
                    color: AppColors.greenDark,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          _RowLabel(label: 'Return', value: _returnDetail, colors: colors, compact: compact),
          _RowLabel(label: 'Risk', value: risk, colors: colors, compact: compact),
          _RowLabel(label: 'Min', value: CurrencyFormatter.format(minimumInvestment), colors: colors, compact: compact),
          SizedBox(height: compact ? 10 : 14),
          ScaleTap(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: compact ? 36 : 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Invest',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 13 : 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;
  final bool compact;

  const _RowLabel({
    required this.label,
    required this.value,
    required this.colors,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: compact ? 12 : 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
