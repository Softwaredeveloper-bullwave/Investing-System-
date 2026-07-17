import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/stock_model.dart';
import 'home_theme_a.dart';

class HomeTrendingStrip extends StatelessWidget {
  final List<StockModel> stocks;
  final VoidCallback? onSeeAll;

  const HomeTrendingStrip({
    super.key,
    required this.stocks,
    this.onSeeAll,
  });

  static const _avatarColors = [
    Color(0xFF047857),
    Color(0xFF1D4ED8),
    Color(0xFF6D28D9),
    Color(0xFF0F766E),
    Color(0xFF4338CA),
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: context.palette.bg,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: onSeeAll != null ? ShellLayout.fabActionClearance : 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Trending Stocks',
                    style: context.typeSection(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onSeeAll != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text('See All', style: context.typeAction()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stocks.length.clamp(0, 8),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final stock = stocks[index];
                return _TrendingStockChip(
                  stock: stock,
                  avatarColor: _avatarColors[index % _avatarColors.length],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ...stocks.take(3).toList().asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: entry.key < 2 ? 10 : 0),
                  child: _TrendingStockRow(
                    stock: entry.value,
                    avatarColor: _avatarColors[entry.key % _avatarColors.length],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _TrendingStockChip extends StatelessWidget {
  final StockModel stock;
  final Color avatarColor;

  const _TrendingStockChip({
    required this.stock,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = stock.isPositive ? p.positive : p.negative;
    final initials = stock.symbol.length >= 2
        ? stock.symbol.substring(0, 2)
        : stock.symbol;

    return SizedBox(
      width: 72,
      height: 96,
      child: ScaleTap(
        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${stock.symbol}'),
        child: Container(
          decoration: HomeThemeA.cardDecoration(context, shadowTint: avatarColor),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    initials,
                    style: ThemeAType.label(size: 12).copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stock.symbol,
                  style: context.typeLabel(12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  IndexFormatter.formatPercent(stock.changePercent),
                  style: context.typeLabel(11, changeColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingStockRow extends StatelessWidget {
  final StockModel stock;
  final Color avatarColor;

  const _TrendingStockRow({
    required this.stock,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = stock.isPositive ? p.positive : p.negative;
    final initials = stock.symbol.length >= 2
        ? stock.symbol.substring(0, 2)
        : stock.symbol;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${stock.symbol}'),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: HomeThemeA.cardDecoration(context, shadowTint: avatarColor),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: ThemeAType.label(size: 13).copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol,
                      style: context.typeCardTitle(14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stock.name,
                      style: context.typeSecondary(13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        IndexFormatter.format(stock.ltp),
                        style: context.typePrice(15),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${IndexFormatter.formatChange(stock.change)} (${IndexFormatter.formatPercent(stock.changePercent)})',
                      style: context.typeLabel(13, changeColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
