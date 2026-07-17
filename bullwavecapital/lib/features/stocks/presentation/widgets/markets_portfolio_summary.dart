import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/portfolio_model.dart';
import 'markets_shared.dart';

class MarketsPortfolioSummary extends StatelessWidget {
  final PortfolioModel? portfolio;
  final bool isLoading;

  const MarketsPortfolioSummary({
    super.key,
    required this.portfolio,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (isLoading && portfolio == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final pf = portfolio;
    if (pf == null) return const SizedBox.shrink();

    final profitPct = pf.totalInvestment > 0
        ? (pf.totalProfit / pf.totalInvestment) * 100
        : pf.growthPercent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: RepaintBoundary(
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          glow: true,
          glowColor: p.primary.withValues(alpha: 0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Portfolio Summary', style: ThemeAType.sectionTitle(color: p.textDark, size: 18)),
              const SizedBox(height: 14),
              Text('Portfolio Value', style: ThemeAType.label(size: 12, color: p.textMuted)),
              const SizedBox(height: 4),
              AnimatedMetricText(
                value: pf.currentValue,
                formatter: CurrencyFormatter.format,
                style: ThemeAType.sectionTitle(color: p.textDark, size: 32),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PnlChip(
                    label: "Today's P&L",
                    value: pf.dayPnl,
                    percent: pf.dayPnlPercent,
                  ),
                  const SizedBox(width: 10),
                  _PnlChip(
                    label: 'Overall Return',
                    value: pf.totalProfit,
                    percent: profitPct,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _StatBox(label: 'Invested', value: pf.totalInvestment)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatBox(label: 'Current Value', value: pf.currentValue)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Profit %',
                      value: profitPct,
                      isPercent: true,
                      highlight: profitPct >= 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PnlChip extends StatelessWidget {
  final String label;
  final double value;
  final double percent;

  const _PnlChip({required this.label, required this.value, required this.percent});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final positive = value >= 0;
    final color = positive ? p.positive : p.negative;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
            const SizedBox(height: 4),
            Text(
              '${positive ? '+' : ''}${CurrencyFormatter.formatCompact(value)}',
              style: ThemeAType.cardTitle(color: color, size: 14),
            ),
            Text(
              '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
              style: ThemeAType.label(size: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final double value;
  final bool isPercent;
  final bool? highlight;

  const _StatBox({
    required this.label,
    required this.value,
    this.isPercent = false,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = highlight == null
        ? p.textDark
        : (highlight! ? p.positive : p.negative);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
          const SizedBox(height: 6),
          AnimatedMetricText(
            value: isPercent ? value.abs() : value,
            formatter: (v) => isPercent
                ? '${value >= 0 ? '+' : '-'}${v.toStringAsFixed(2)}%'
                : CurrencyFormatter.formatCompact(v),
            style: ThemeAType.cardTitle(color: color, size: 13),
          ),
        ],
      ),
    );
  }
}
