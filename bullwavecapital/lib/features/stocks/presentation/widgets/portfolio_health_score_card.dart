import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/portfolio_health_model.dart';

class PortfolioHealthScoreCard extends StatelessWidget {
  final PortfolioHealthModel? health;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const PortfolioHealthScoreCard({
    super.key,
    required this.health,
    this.isLoading = false,
    this.onRefresh,
  });

  Color _scoreColor(ThemePalette p, int score) {
    if (score >= 70) return p.positive;
    if (score >= 55) return const Color(0xFFF59E0B);
    return p.negative;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (isLoading && health == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final h = health;
    if (h == null) return const SizedBox.shrink();
    final color = _scoreColor(p, h.score);

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      glow: true,
      glowColor: color.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Portfolio Health', style: ThemeAType.sectionTitle(color: p.textDark, size: 18)),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh_rounded, color: p.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: h.score / 100,
                        strokeWidth: 8,
                        backgroundColor: p.borderLight,
                        color: color,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${h.score}', style: ThemeAType.sectionTitle(color: color, size: 26)),
                        Text(h.gradeLetter, style: ThemeAType.label(size: 12, color: p.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.label, style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
                    const SizedBox(height: 4),
                    Text(h.summary, style: ThemeAType.body(color: p.textGrey, size: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Chip(label: '${h.holdingsCount} holdings', p: p),
                        _Chip(label: 'Drift ${h.driftScore}', p: p),
                        if (h.portfolioValue > 0)
                          _Chip(label: CurrencyFormatter.formatCompact(h.portfolioValue), p: p),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (h.factors.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...h.factors.take(4).map((f) {
              final factorColor = f.isPositive ? p.positive : p.negative;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      f.isPositive ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 16,
                      color: factorColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.label, style: ThemeAType.cardTitle(color: p.textDark, size: 13)),
                          Text(f.detail, style: ThemeAType.body(color: p.textGrey, size: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final ThemePalette p;

  const _Chip({required this.label, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.borderLight),
      ),
      child: Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
    );
  }
}
