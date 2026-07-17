import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../data/heat_map_mock_data.dart';
import 'markets_shared.dart';

class MarketHeatMapWidget extends StatefulWidget {
  const MarketHeatMapWidget({super.key});

  @override
  State<MarketHeatMapWidget> createState() => _MarketHeatMapWidgetState();
}

class _MarketHeatMapWidgetState extends State<MarketHeatMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _layoutRows(HeatMapMockData.stocks);

    return ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(_scale),
      child: RepaintBoundary(
        child: Column(
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: row.height,
                child: Row(
                  children: row.tiles.map((tile) {
                    return Expanded(
                      flex: tile.flex,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _HeatTileWidget(stock: tile.stock),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_HeatRow> _layoutRows(List<HeatMapStock> stocks) {
    final sorted = [...stocks]..sort((a, b) => b.marketCapCr.compareTo(a.marketCapCr));
    final rows = <_HeatRow>[];
    var buffer = <_HeatTileData>[];
    var weight = 0.0;

    for (final stock in sorted) {
      final flex = (stock.marketCapCr / 200000).round().clamp(1, 4);
      if (weight + flex > 8 && buffer.isNotEmpty) {
        rows.add(_HeatRow(
          height: buffer.map((t) => t.flex).reduce((a, b) => a + b) > 6 ? 88.0 : 72.0,
          tiles: buffer,
        ));
        buffer = [];
        weight = 0;
      }
      buffer.add(_HeatTileData(stock: stock, flex: flex));
      weight += flex;
    }
    if (buffer.isNotEmpty) {
      rows.add(_HeatRow(height: 76, tiles: buffer));
    }
    return rows;
  }
}

class MarketsHeatMapSection extends StatelessWidget {
  final VoidCallback? onViewAll;

  const MarketsHeatMapSection({
    super.key,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketsSectionHeader(
          title: 'Market Heat Map',
          subtitle: "Today's Market Performance",
          actionLabel: 'View All',
          onAction: onViewAll,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: MarketHeatMapWidget(),
        ),
      ],
    );
  }
}

class _HeatRow {
  final double height;
  final List<_HeatTileData> tiles;

  const _HeatRow({required this.height, required this.tiles});
}

class _HeatTileData {
  final HeatMapStock stock;
  final int flex;

  const _HeatTileData({required this.stock, this.flex = 1});
}

class _HeatTileWidget extends StatelessWidget {
  final HeatMapStock stock;

  const _HeatTileWidget({required this.stock});

  @override
  Widget build(BuildContext context) {
    final shortSymbol = stock.symbol.length > 8 ? stock.symbol.substring(0, 6) : stock.symbol;

    return Hero(
      tag: 'heatmap-${stock.symbol}',
      child: ScaleTap(
        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${stock.symbol}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: stock.heatColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: stock.heatColor.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shortSymbol,
                style: ThemeAType.label(size: 11, color: Colors.white).copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                stock.changeLabel,
                style: ThemeAType.cardTitle(color: Colors.white, size: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
