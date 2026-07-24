import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// Prominent "not real money" label reused across every Paper Trading
/// screen — dashboard, order book, journal, analytics, risk limits.
class SimulationOnlyBadge extends StatelessWidget {
  final bool compact;

  const SimulationOnlyBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 5 : 8),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_rounded, size: compact ? 13 : 15, color: AppColors.brandOrange),
          const SizedBox(width: 6),
          Text(
            'SIMULATION ONLY — NO REAL MONEY',
            style: TextStyle(
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.brandOrange,
            ),
          ),
        ],
      ),
    );
  }
}
