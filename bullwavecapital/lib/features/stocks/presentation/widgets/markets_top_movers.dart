import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/stock_model.dart';
import 'markets_shared.dart';

enum TopMoverTab { gainers, losers, active, weekHigh, weekLow }

class MarketsTopMovers extends StatefulWidget {
  final List<StockModel> stocks;

  const MarketsTopMovers({super.key, required this.stocks});

  @override
  State<MarketsTopMovers> createState() => _MarketsTopMoversState();
}

class _MarketsTopMoversState extends State<MarketsTopMovers> {
  TopMoverTab _tab = TopMoverTab.gainers;

  List<StockModel> _filtered() {
    final list = [...widget.stocks];
    switch (_tab) {
      case TopMoverTab.gainers:
        return list.where((s) => s.changePercent > 0).toList()
          ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
      case TopMoverTab.losers:
        return list.where((s) => s.changePercent < 0).toList()
          ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
      case TopMoverTab.active:
        return list..sort((a, b) => b.volume.compareTo(a.volume));
      case TopMoverTab.weekHigh:
        return list
          ..sort((a, b) => (b.ltp / b.week52High).compareTo(a.ltp / a.week52High));
      case TopMoverTab.weekLow:
        return list
          ..sort((a, b) => (a.ltp / a.week52Low).compareTo(b.ltp / b.week52Low));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tabs = const [
      (TopMoverTab.gainers, 'Top Gainers'),
      (TopMoverTab.losers, 'Top Losers'),
      (TopMoverTab.active, 'Most Active'),
      (TopMoverTab.weekHigh, '52W High'),
      (TopMoverTab.weekLow, '52W Low'),
    ];

    final items = _filtered().take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MarketsSectionHeader(title: 'Top Movers'),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (tab, label) = tabs[index];
              final selected = _tab == tab;
              return ScaleTap(
                onTap: () => setState(() => _tab = tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? p.primary.withValues(alpha: 0.15) : p.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? p.primary.withValues(alpha: 0.5) : p.borderLight,
                    ),
                  ),
                  child: Text(
                    label,
                    style: ThemeAType.label(
                      size: 12,
                      color: selected ? p.primary : p.textGrey,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: items.isEmpty
              ? Padding(
                  key: ValueKey(_tab),
                  padding: const EdgeInsets.all(24),
                  child: Text('No data for this filter', style: ThemeAType.body(color: p.textMuted)),
                )
              : Column(
                  key: ValueKey(_tab),
                  children: items
                      .map(
                        (stock) => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _MoverRow(stock: stock, tab: _tab),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _MoverRow extends StatelessWidget {
  final StockModel stock;
  final TopMoverTab tab;

  const _MoverRow({required this.stock, required this.tab});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final positive = stock.changePercent >= 0;
    final color = positive ? p.positive : p.negative;

    String trailing;
    switch (tab) {
      case TopMoverTab.active:
        trailing = '${(stock.volume / 100000).toStringAsFixed(1)}L vol';
      case TopMoverTab.weekHigh:
        trailing = '${((stock.ltp / stock.week52High) * 100).toStringAsFixed(1)}% of 52W H';
      case TopMoverTab.weekLow:
        trailing = '${((stock.ltp / stock.week52Low) * 100).toStringAsFixed(1)}% of 52W L';
      default:
        trailing = IndexFormatter.formatPercent(stock.changePercent);
    }

    return ScaleTap(
      onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${stock.symbol}'),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.symbol, style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
                  Text(stock.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThemeAType.body(color: p.textGrey, size: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(stock.ltp), style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
                Text(trailing, style: ThemeAType.label(size: 12, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
