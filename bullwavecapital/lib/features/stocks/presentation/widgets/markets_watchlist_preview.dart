import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_market_provider.dart';
import 'markets_shared.dart';

class MarketsWatchlistPreview extends StatelessWidget {
  const MarketsWatchlistPreview({super.key});

  static const _avatarColors = [
    Color(0xFF047857),
    Color(0xFF1D4ED8),
    Color(0xFF6D28D9),
    Color(0xFF0F766E),
    Color(0xFFBE123C),
  ];

  @override
  Widget build(BuildContext context) {
    final market = context.watch<StockMarketProvider>();
    final stocks = market.watchlistStocks.take(5).toList();

    if (stocks.isEmpty && !market.watchlistLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketsSectionHeader(
          title: 'Watchlist',
          subtitle: 'Your saved stocks at a glance',
          actionLabel: 'See All',
          onAction: () => context.push(AppRoutes.watchlist),
        ),
        if (market.watchlistLoading && stocks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          ...stocks.map((stock) => _WatchlistRow(stock: stock)),
      ],
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  final StockModel stock;

  const _WatchlistRow({required this.stock});

  Color _avatarColor(String symbol) =>
      MarketsWatchlistPreview._avatarColors[symbol.hashCode.abs() % MarketsWatchlistPreview._avatarColors.length];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final market = context.read<StockMarketProvider>();
    final changeColor = stock.isPositive ? p.positive : p.negative;
    final initials = stock.symbol.length >= 2 ? stock.symbol.substring(0, 2) : stock.symbol;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: ScaleTap(
        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${stock.symbol}'),
        child: GlassCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _avatarColor(stock.symbol), shape: BoxShape.circle),
                child: Text(initials, style: ThemeAType.label(size: 12, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stock.symbol, style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
                    Text(
                      stock.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.body(color: p.textGrey, size: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(stock.ltp), style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
                  Text(
                    IndexFormatter.formatPercent(stock.changePercent),
                    style: ThemeAType.label(size: 12, color: changeColor),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => market.toggleWatchlist(stock.symbol),
                icon: Icon(
                  Icons.bookmark_rounded,
                  color: p.primary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
