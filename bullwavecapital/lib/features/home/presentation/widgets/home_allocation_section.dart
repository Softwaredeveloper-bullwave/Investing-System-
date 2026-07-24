import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/donut_ring_chart.dart';
import 'home_theme_a.dart';

class AllocationSlice {
  final String label;
  final double value;
  final Color color;

  const AllocationSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Real-money portfolio allocation — one ring card per holding category
/// (equity, cash, goal/SIP plans, and F&O/commodities when present). Only
/// categories with a positive balance are shown, computed from live
/// provider data (never paper-trading virtual balances).
class HomeAllocationSection extends StatelessWidget {
  final List<AllocationSlice> slices;
  final VoidCallback? onSeeAll;

  const HomeAllocationSection({
    super.key,
    required this.slices,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = slices.where((s) => s.value > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final total = visible.fold<double>(0, (sum, s) => sum + s.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Portfolio Allocation',
          actionLabel: 'View All',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _AllocationCard(
                  slice: visible[i],
                  percent: total > 0 ? (visible[i].value / total) * 100 : 0,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final AllocationSlice slice;
  final double percent;

  const _AllocationCard({required this.slice, required this.percent});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: p.cardDecoration(),
      child: Column(
        children: [
          DonutRingChart(
            percent: percent,
            color: slice.color,
            trackColor: slice.color.withValues(alpha: 0.14),
            size: 52,
            strokeWidth: 5,
            center: Text(
              '${percent.toStringAsFixed(0)}%',
              style: ThemeAType.label(size: 11, color: p.textDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slice.label,
            style: ThemeAType.secondary(size: 11, color: p.textGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.formatCompact(slice.value),
            style: ThemeAType.label(size: 12, color: p.textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Default color set for the four common allocation categories, chosen
/// from the Forest Green palette family so rings stay on-brand.
class AllocationColors {
  AllocationColors._();
  static const equity = AppColors.brandPrimary;
  static const cash = AppColors.green;
  static const goals = AppColors.brandMint;
  static const fno = AppColors.brandGold;
}
