import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/robinhood_line_chart.dart';
import 'home_theme_a.dart';

/// Dark forest-green hero card showing total portfolio value, today's
/// change, and a glowing area chart — the visual anchor of the Home screen.
class HomeHeroPortfolioCard extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final double portfolioValue;
  final double dayPnl;
  final double dayPnlPercent;
  final List<double> chartValues;
  final VoidCallback? onTap;

  const HomeHeroPortfolioCard({
    super.key,
    required this.greeting,
    required this.subtitle,
    required this.portfolioValue,
    required this.dayPnl,
    required this.dayPnlPercent,
    required this.chartValues,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = dayPnl >= 0;
    final values = chartValues.length >= 2
        ? chartValues
        : List<double>.generate(8, (i) => portfolioValue * (0.94 + i * 0.01));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandPrimary, AppColors.brandPrimaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: ThemeAType.secondary(
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: ThemeAType.sectionTitle(size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Today',
                          style: ThemeAType.label(size: 12, color: Colors.white),
                        ),
                        const SizedBox(width: 3),
                        Icon(PhosphorIcons.caretDown, size: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Total Portfolio Value',
                    style: ThemeAType.secondary(size: 13, color: Colors.white.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(width: 6),
                  Icon(PhosphorIcons.info, size: 13, color: Colors.white.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.format(portfolioValue),
                  style: ThemeAType.heading(size: 34, color: Colors.white).copyWith(letterSpacing: -0.8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isProfit ? PhosphorIcons.trendUp : PhosphorIcons.trendDown,
                    size: 14,
                    color: AppColors.brandMint,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${isProfit ? '+' : ''}${CurrencyFormatter.formatCompact(dayPnl)} '
                      '(${isProfit ? '+' : ''}${dayPnlPercent.toStringAsFixed(2)}%) today',
                      style: ThemeAType.label(size: 13, color: AppColors.brandMint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RobinhoodLineChart(
                values: values,
                height: 88,
                isPositive: isProfit,
                lineColorOverride: isProfit ? Colors.white : const Color(0xFFFCA5A5),
                fillColorOverride: isProfit ? AppColors.brandMint : const Color(0xFFFCA5A5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
