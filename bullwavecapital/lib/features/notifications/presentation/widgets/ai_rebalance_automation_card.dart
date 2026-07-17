import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/portfolio_rebalance_model.dart';

class AiRebalanceAutomationCard extends StatelessWidget {
  final PortfolioRebalanceModel? status;
  final bool isChecking;
  final VoidCallback onRunCheck;

  const AiRebalanceAutomationCard({
    super.key,
    required this.status,
    required this.isChecking,
    required this.onRunCheck,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final drift = status?.driftScore ?? 0;
    final needsAction = status?.needsRebalance ?? false;
    final driftColor = drift >= 55 ? AppColors.error : drift >= 35 ? AppColors.warning : p.positive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(18),
        glow: true,
        glowColor: ThemeA.primary.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThemeA.primary.withValues(alpha: 0.3), p.card],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded, color: ThemeA.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Portfolio Rebalancing', style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
                      Text(
                        'Automation monitors sector drift & concentration',
                        style: ThemeAType.body(color: p.textGrey, size: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.positive.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('ACTIVE', style: ThemeAType.label(size: 10, color: p.positive)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MetricChip(
                  label: 'Drift score',
                  value: '$drift/100',
                  color: driftColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricChip(
                    label: 'Portfolio',
                    value: status != null && status!.portfolioValue > 0
                        ? CurrencyFormatter.formatCompact(status!.portfolioValue)
                        : '—',
                    color: p.textDark,
                  ),
                ),
              ],
            ),
            if (status != null && status!.headline.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                status!.headline,
                style: ThemeAType.body(color: p.textGrey, size: 13),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isChecking ? null : onRunCheck,
                    icon: isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.psychology_rounded, size: 18),
                    label: Text(isChecking ? 'Analyzing…' : 'Run AI check'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.portfolioAnalytics),
                  child: const Text('View'),
                ),
              ],
            ),
            if (needsAction) ...[
              const SizedBox(height: 10),
              Text(
                'Rebalance alert will appear below when drift exceeds guardrails.',
                style: ThemeAType.label(size: 11, color: p.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: ThemeAType.cardTitle(color: color, size: 14)),
        ],
      ),
    );
  }
}
