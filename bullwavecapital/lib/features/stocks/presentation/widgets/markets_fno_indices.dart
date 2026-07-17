import 'package:flutter/material.dart';

import '../../../../core/constants/fno_index_catalog.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/market_index_model.dart';
import '../../../fno/fno_navigation.dart';
import 'markets_shared.dart';

/// F&O index shortcuts — tap opens full index hub (chart, analysis, option chain).
class MarketsFnoIndicesSection extends StatelessWidget {
  final List<MarketIndexModel> liveIndices;

  const MarketsFnoIndicesSection({super.key, required this.liveIndices});

  double? _spotFor(String symbol) {
    final keys = {
      'NIFTY': ['NIFTY', 'NIFTY 50', 'NIFTY50'],
      'SENSEX': ['SENSEX'],
      'BANKNIFTY': ['BANKNIFTY', 'BANK NIFTY'],
      'FINNIFTY': ['FINNIFTY', 'FIN NIFTY'],
      'MIDCPNIFTY': ['MIDCPNIFTY', 'NIFTY MIDCAP'],
      'BANKEX': ['BANKEX', 'BSE BANKEX'],
    };
    final aliases = keys[symbol] ?? [symbol];
    for (final idx in liveIndices) {
      final name = idx.shortName.toUpperCase();
      if (aliases.any((a) => name.contains(a))) return idx.value;
    }
    return null;
  }

  double? _changeFor(String symbol) {
    final keys = {
      'NIFTY': ['NIFTY', 'NIFTY 50'],
      'SENSEX': ['SENSEX'],
      'BANKNIFTY': ['BANKNIFTY', 'BANK NIFTY'],
    };
    final aliases = keys[symbol] ?? [symbol];
    for (final idx in liveIndices) {
      final name = idx.shortName.toUpperCase();
      if (aliases.any((a) => name.contains(a))) return idx.changePercent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketsSectionHeader(
          title: 'Index F&O',
          subtitle: 'Charts · Analysis · Option chain',
          actionLabel: 'All chains',
          onAction: () => openFnoFeature(context, AppRoutes.optionChain, query: {'symbol': 'NIFTY'}),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: FnoIndexCatalog.indices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final meta = FnoIndexCatalog.indices[index];
              return _FnoIndexCard(
                meta: meta,
                spot: _spotFor(meta.symbol),
                changePercent: _changeFor(meta.symbol),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FnoIndexCard extends StatelessWidget {
  final FnoIndexMeta meta;
  final double? spot;
  final double? changePercent;

  const _FnoIndexCard({
    required this.meta,
    this.spot,
    this.changePercent,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final change = changePercent ?? 0.0;
    final positive = change >= 0;
    final changeColor = positive ? p.positive : p.negative;

    return ScaleTap(
      onTap: () => openFnoFeature(
        context,
        AppRoutes.indexFnoHub,
        query: {'symbol': meta.symbol},
      ),
      child: SizedBox(
        width: 156,
        child: GlassCard(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(meta.exchange, style: ThemeAType.label(size: 9, color: p.primary)),
                  ),
                  const Spacer(),
                  Icon(Icons.candlestick_chart_rounded, size: 16, color: p.textMuted),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                meta.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThemeAType.cardTitle(color: p.textDark, size: 13),
              ),
              const Spacer(),
              if (spot != null)
                Text(IndexFormatter.format(spot!), style: ThemeAType.cardTitle(color: p.textDark, size: 15))
              else
                Text('—', style: ThemeAType.cardTitle(color: p.textMuted, size: 15)),
              const SizedBox(height: 2),
              Text(
                changePercent != null ? IndexFormatter.formatPercent(change) : 'Tap for chain',
                style: ThemeAType.label(size: 11, color: changeColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
