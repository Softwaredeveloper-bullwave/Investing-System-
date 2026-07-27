import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../models/market_index_model.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import 'markets_shared.dart';

class MarketOverviewItem {
  final String label;
  final double value;
  final double changePercent;
  final bool isPositive;

  const MarketOverviewItem({
    required this.label,
    required this.value,
    required this.changePercent,
    required this.isPositive,
  });

  factory MarketOverviewItem.fromIndex(MarketIndexModel index) => MarketOverviewItem(
        label: index.shortName,
        value: index.value,
        changePercent: index.changePercent,
        isPositive: index.isPositive,
      );
}

class MarketsPremiumOverview extends StatelessWidget {
  final List<MarketIndexModel> indices;

  const MarketsPremiumOverview({super.key, required this.indices});

  static const _extras = [
    ('India VIX', 11.42, -2.18, false),
    ('Gold', 72580.0, 0.64, true),
    ('Silver', 89240.0, -0.38, false),
    ('USD/INR', 83.24, 0.12, true),
  ];

  List<MarketOverviewItem> _buildItems() {
    final map = {for (final i in indices) i.shortName.toUpperCase(): i};
    final items = <MarketOverviewItem>[];

    void addFromApi(String key, String label) {
      final idx = map[key] ?? map[label.toUpperCase()];
      if (idx != null) {
        items.add(MarketOverviewItem.fromIndex(idx));
      }
    }

    addFromApi('NIFTY', 'Nifty 50');
    addFromApi('NIFTY 50', 'Nifty 50');
    addFromApi('SENSEX', 'Sensex');
    addFromApi('BANKNIFTY', 'Bank Nifty');
    addFromApi('BANK NIFTY', 'Bank Nifty');

    if (items.isEmpty && indices.isNotEmpty) {
      items.addAll(indices.take(3).map(MarketOverviewItem.fromIndex));
    }

    for (final (label, value, change, positive) in _extras) {
      items.add(MarketOverviewItem(
        label: label,
        value: value,
        changePercent: change,
        isPositive: positive,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = _buildItems();
    final marketOpen = isIndianMarketOpen();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: RepaintBoundary(
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Market Overview',
                      style: ThemeAType.sectionTitle(color: p.textDark, size: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _MarketStatusBadge(isOpen: marketOpen),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _OverviewTile(item: item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketStatusBadge extends StatelessWidget {
  final bool isOpen;

  const _MarketStatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = isOpen ? p.positive : p.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Market Open' : 'Market Closed',
            style: ThemeAType.label(size: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final MarketOverviewItem item;

  const _OverviewTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = item.isPositive ? p.positive : p.negative;
    final valueText = item.label == 'USD/INR'
        ? item.value.toStringAsFixed(2)
        : item.value >= 1000
            ? IndexFormatter.format(item.value)
            : item.value.toStringAsFixed(2);

    return Container(
      width: 128,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: p.isDark ? 0.55 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: ThemeAType.label(size: 11, color: p.textMuted), maxLines: 1),
          const Spacer(),
          Text(valueText, style: ThemeAType.cardTitle(color: p.textDark, size: 15)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                item.isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                size: 18,
                color: changeColor,
              ),
              Expanded(
                child: Text(
                  IndexFormatter.formatPercent(item.changePercent),
                  style: ThemeAType.label(size: 12, color: changeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: CustomPaint(
              painter: _SparklinePainter(
                isPositive: item.isPositive,
                color: changeColor.withValues(alpha: 0.85),
                seed: item.label.hashCode,
              ),
              size: const Size(double.infinity, 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final bool isPositive;
  final Color color;
  final int seed;

  _SparklinePainter({required this.isPositive, required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final points = List.generate(8, (i) {
      final base = isPositive ? 0.55 - i * 0.03 : 0.35 + i * 0.03;
      return (base + (rng.nextDouble() - 0.5) * 0.12).clamp(0.08, 0.92);
    });

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => false;
}
