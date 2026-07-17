import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/goal_plan_model.dart';
import '../../data/goal_return_tiers.dart';

class GoalReturnTiersStrip extends StatelessWidget {
  final double? selectedMonthly;
  final List<GoalReturnTierModel> tiers;
  final bool onDarkBackground;
  final bool compact;

  const GoalReturnTiersStrip({
    super.key,
    this.selectedMonthly,
    List<GoalReturnTierModel>? tiers,
    this.onDarkBackground = true,
    this.compact = false,
  }) : tiers = tiers ?? GoalReturnTiersCatalog.tiers;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GoalReturnTiersCarousel(
        selectedMonthly: selectedMonthly,
        tiers: tiers,
        onDarkBackground: onDarkBackground,
      );
    }

    final active = selectedMonthly != null
        ? GoalReturnTiersCatalog.tierForMonthly(selectedMonthly!)
        : null;
    final subtitle = onDarkBackground
        ? Colors.white.withValues(alpha: 0.65)
        : context.appColors.textSecondary;
    final titleColor = onDarkBackground ? Colors.white : context.appColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights_rounded, size: 18, color: AppColors.green.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            Text('Return plans', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: titleColor)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Earn more as your monthly SIP grows — returns credited every installment.',
          style: TextStyle(fontSize: 12, height: 1.35, color: subtitle),
        ),
        const SizedBox(height: 14),
        ...tiers.map((tier) {
          final isActive = active?.id == tier.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TierRow(tier: tier, isActive: isActive, onDarkBackground: onDarkBackground),
          );
        }),
      ],
    );
  }
}

/// Horizontal tier cards for compact hero layouts.
class GoalReturnTiersCarousel extends StatelessWidget {
  final double? selectedMonthly;
  final List<GoalReturnTierModel> tiers;
  final bool onDarkBackground;

  const GoalReturnTiersCarousel({
    super.key,
    this.selectedMonthly,
    required this.tiers,
    this.onDarkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = selectedMonthly != null
        ? GoalReturnTiersCatalog.tierForMonthly(selectedMonthly!)
        : null;

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final tier = tiers[index];
          final isActive = active?.id == tier.id;
          return _CompactTierCard(
            tier: tier,
            isActive: isActive,
            onDarkBackground: onDarkBackground,
          );
        },
      ),
    );
  }
}

class _CompactTierCard extends StatelessWidget {
  final GoalReturnTierModel tier;
  final bool isActive;
  final bool onDarkBackground;

  const _CompactTierCard({
    required this.tier,
    required this.isActive,
    required this.onDarkBackground,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = onDarkBackground ? Colors.white : context.appColors.textPrimary;
    final subColor = onDarkBackground ? Colors.white.withValues(alpha: 0.58) : context.appColors.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: onDarkBackground
              ? [
                  tier.color.withValues(alpha: isActive ? 0.28 : 0.14),
                  Colors.white.withValues(alpha: isActive ? 0.1 : 0.04),
                ]
              : [
                  tier.color.withValues(alpha: isActive ? 0.16 : 0.08),
                  context.appColors.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tier.color.withValues(alpha: isActive ? 0.55 : 0.22),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tier.id == 'elite'
                    ? Icons.workspace_premium_rounded
                    : tier.id == 'growth'
                        ? Icons.trending_up_rounded
                        : Icons.savings_rounded,
                color: tier.color,
                size: 16,
              ),
              const Spacer(),
              Text(
                '${tier.annualReturnRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isActive ? AppColors.green : titleColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            tier.name,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: titleColor),
          ),
          const SizedBox(height: 2),
          Text(
            tier.rangeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: subColor),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final GoalReturnTierModel tier;
  final bool isActive;
  final bool onDarkBackground;

  const _TierRow({
    required this.tier,
    required this.isActive,
    required this.onDarkBackground,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = onDarkBackground
        ? (isActive ? tier.color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06))
        : (isActive ? tier.color.withValues(alpha: 0.12) : colors.surfaceSecondary);
    final border = onDarkBackground
        ? (isActive ? tier.color.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.08))
        : (isActive ? tier.color.withValues(alpha: 0.4) : colors.border);
    final titleColor = onDarkBackground ? Colors.white : colors.textPrimary;
    final subColor = onDarkBackground ? Colors.white.withValues(alpha: 0.55) : colors.textMuted;
    final rateColor = isActive ? AppColors.green : titleColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: isActive ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tier.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tier.id == 'elite'
                  ? Icons.workspace_premium_rounded
                  : tier.id == 'growth'
                      ? Icons.trending_up_rounded
                      : Icons.savings_rounded,
              color: tier.color,
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
                    Text(tier.name, style: TextStyle(fontWeight: FontWeight.w800, color: titleColor)),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tier.color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOUR PLAN',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tier.color),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(tier.rangeLabel, style: TextStyle(fontSize: 11, color: subColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tier.annualReturnRate.toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: rateColor),
              ),
              Text('p.a.', style: TextStyle(fontSize: 10, color: subColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class GoalProjectionCard extends StatelessWidget {
  final double monthlyContribution;
  final int durationMonths;
  final double annualReturnRate;
  final GoalReturnTierModel tier;
  final Color? accent;

  const GoalProjectionCard({
    super.key,
    required this.monthlyContribution,
    required this.durationMonths,
    required this.annualReturnRate,
    required this.tier,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final projection = GoalReturnTiersCatalog.projectedMaturity(
      monthlyContribution: monthlyContribution,
      months: durationMonths,
      annualReturnRate: annualReturnRate,
    );
    final color = accent ?? tier.color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            AppColors.brandPrimary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tier.name} • ${annualReturnRate.toStringAsFixed(0)}% p.a.',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: color),
                ),
              ),
              const Spacer(),
              Icon(Icons.auto_graph_rounded, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text('Est. at maturity', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(projection.maturity),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                label: 'You invest',
                value: CurrencyFormatter.format(projection.invested),
                textPrimary: colors.textPrimary,
                textMuted: colors.textMuted,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Est. returns',
                value: CurrencyFormatter.format(projection.returns),
                highlight: true,
                textPrimary: colors.textPrimary,
                textMuted: colors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Returns accrue monthly on your balance. Withdraw anytime to wallet.',
            style: TextStyle(fontSize: 11, height: 1.35, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color textPrimary;
  final Color textMuted;

  const _StatChip({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textMuted,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: textMuted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: highlight ? AppColors.green : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalReturnBadge extends StatelessWidget {
  final double annualReturnRate;
  final bool compact;

  const GoalReturnBadge({super.key, required this.annualReturnRate, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward_rounded, size: compact ? 12 : 14, color: AppColors.green),
          const SizedBox(width: 4),
          Text(
            '${annualReturnRate.toStringAsFixed(0)}% p.a.',
            style: TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}
