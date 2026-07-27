import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_market_provider.dart';

class StockListTile extends StatelessWidget {
  final StockModel stock;
  final VoidCallback? onTap;
  final bool showWatchlistButton;

  const StockListTile({
    super.key,
    required this.stock,
    this.onTap,
    this.showWatchlistButton = true,
  });

  static const _avatarColors = [
    Color(0xFF047857),
    Color(0xFF1D4ED8),
    Color(0xFF6D28D9),
    Color(0xFF0F766E),
  ];

  Color _avatarColor(String symbol) =>
      _avatarColors[symbol.hashCode.abs() % _avatarColors.length];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = stock.isPositive ? p.positive : p.negative;
    final market = context.watch<StockMarketProvider>();
    final inWatchlist = market.isInWatchlist(stock.symbol);
    final avatarColor = _avatarColor(stock.symbol);
    final initials = stock.symbol.length >= 2
        ? stock.symbol.substring(0, 2)
        : stock.symbol;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => context.push('${AppRoutes.stockDetail}?symbol=${stock.symbol}'),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: p.cardDecoration(shadowTint: avatarColor, radius: 22),
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
                    style: context.typeLabel(13, Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stock.symbol, style: context.typeCardTitle(15)),
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
                if (showWatchlistButton) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      inWatchlist ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: inWatchlist ? p.primary : p.textGrey,
                      size: 22,
                    ),
                    onPressed: () async {
                      final err = await market.toggleWatchlist(stock.symbol);
                      if (context.mounted && err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LivePriceBadge extends StatelessWidget {
  const LivePriceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.positive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.positive.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: p.positive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Live',
            style: ThemeAType.label(size: 11, color: p.positive),
          ),
        ],
      ),
    );
  }
}
