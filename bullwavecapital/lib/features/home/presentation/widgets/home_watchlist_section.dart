import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/stock_model.dart';
import 'home_theme_a.dart';

/// Compact watchlist strip shown on Home — up to 4 saved symbols with
/// live LTP + change%, reusing [StockMarketProvider.watchlistStocks].
class HomeWatchlistSection extends StatelessWidget {
  final List<StockModel> stocks;
  final VoidCallback? onSeeAll;
  final void Function(StockModel stock)? onTapStock;

  const HomeWatchlistSection({
    super.key,
    required this.stocks,
    this.onSeeAll,
    this.onTapStock,
  });

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) return const SizedBox.shrink();
    final shown = stocks.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Watchlist',
          actionLabel: 'View All',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _WatchlistRow(
                stock: shown[i],
                onTap: onTapStock == null ? null : () => onTapStock!(shown[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  final StockModel stock;
  final VoidCallback? onTap;

  const _WatchlistRow({required this.stock, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isPositive = stock.isPositive;
    final changeColor = isPositive ? p.positive : p.negative;

    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: p.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: p.iconCircleDecoration(),
              child: Text(
                stock.symbol.isNotEmpty ? stock.symbol.substring(0, 1) : '?',
                style: ThemeAType.label(size: 14, color: p.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.symbol,
                    style: ThemeAType.cardTitle(size: 14, color: p.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.name,
                    style: ThemeAType.muted(size: 12, color: p.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatDecimal(stock.ltp),
                  style: ThemeAType.cardTitle(size: 14, color: p.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPositive ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                  style: ThemeAType.label(size: 12, color: changeColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
