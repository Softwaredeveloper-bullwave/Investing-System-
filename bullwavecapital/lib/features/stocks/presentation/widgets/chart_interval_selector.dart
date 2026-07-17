import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import 'stock_detail_chart.dart';

class ChartIntervalSelector extends StatelessWidget {
  final String selectedLabel;
  final ValueChanged<String> onSelected;

  const ChartIntervalSelector({
    super.key,
    required this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: stockChartIntervals.map((item) {
          final selected = item.label == selectedLabel;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: selected
                  ? AppColors.brandOrange.withValues(alpha: 0.15)
                  : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onSelected(item.label),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? AppColors.brandOrange.withValues(alpha: 0.5)
                          : colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? AppColors.brandOrange : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
