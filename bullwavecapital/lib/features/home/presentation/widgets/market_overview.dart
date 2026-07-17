import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../models/market_index_model.dart';
import 'home_theme_a.dart';

class MarketOverview extends StatelessWidget {
  final List<MarketIndexModel> indices;

  const MarketOverview({super.key, required this.indices});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text('Market Live', style: context.typeSection(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: p.primaryPillDecoration(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.positive,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: p.primary.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Live',
                      style: context.typeLabel(12, p.positive),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (indices.isEmpty)
            Text(
              'Market data unavailable',
              style: context.typeSecondary(13),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: indices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = indices[index];
                  return SizedBox(
                    width: 132,
                    height: 92,
                    child: _MarketLiveCard(
                      label: item.shortName,
                      value: IndexFormatter.format(item.value),
                      change: IndexFormatter.formatPercent(item.changePercent),
                      isPositive: item.isPositive,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketLiveCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool isPositive;

  const _MarketLiveCard({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = isPositive ? p.positive : p.negative;

    return Container(
      height: double.infinity,
      decoration: HomeThemeA.cardDecoration(
        context,
        shadowTint: isPositive ? p.primary : p.negative,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: context.typeCardTitle(13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: context.typePrice(17),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isPositive
                            ? PhosphorIcons.arrowUpRight
                            : PhosphorIcons.arrowDownRight,
                        size: 12,
                        color: changeColor,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          change,
                          style: context.typeLabel(12, changeColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _MiniSparkline(isPositive: isPositive, color: changeColor),
          ],
        ),
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final bool isPositive;
  final Color color;

  const _MiniSparkline({
    required this.isPositive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 32,
      child: CustomPaint(
        painter: _SparklinePainter(
          isPositive: isPositive,
          color: color.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final bool isPositive;
  final Color color;

  _SparklinePainter({
    required this.isPositive,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = isPositive
        ? [0.72, 0.58, 0.64, 0.42, 0.48, 0.28]
        : [0.28, 0.42, 0.36, 0.58, 0.52, 0.72];

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
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);

    final dot = points.last;
    canvas.drawCircle(
      Offset(size.width, dot * size.height),
      2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.isPositive != isPositive || oldDelegate.color != color;
}
