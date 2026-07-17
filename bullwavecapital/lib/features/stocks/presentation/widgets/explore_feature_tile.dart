import 'package:flutter/material.dart';

import '../../../../core/constants/assets.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/modern_icon_badge.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';

class ExploreFeatureItem {
  final IconData icon;
  final String? iconAsset;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  final String? badge;

  const ExploreFeatureItem({
    required this.icon,
    this.iconAsset,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.badge,
  });
}

/// Premium explore card with quick-access row + services grid.
class PremiumExploreCard extends StatelessWidget {
  final List<ExploreFeatureItem> quickAccess;
  final List<ExploreFeatureItem> services;

  const PremiumExploreCard({
    super.key,
    required this.quickAccess,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: quickAccess
                  .map(
                    (item) => Expanded(
                      child: PremiumServiceTile(
                        item: item,
                        iconSize: 58,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _ServicesGrid(items: services),
          ],
        ),
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  final List<ExploreFeatureItem> items;

  const _ServicesGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.length <= 4) {
      return Row(
        children: items
            .map(
              (item) => Expanded(
                child: PremiumServiceTile(item: item, iconSize: 52),
              ),
            )
            .toList(),
      );
    }

    final row1 = items.take(4).toList();
    final row2 = items.skip(4).toList();

    return Column(
      children: [
        Row(
          children: row1
              .map(
                (item) => Expanded(
                  child: PremiumServiceTile(item: item, iconSize: 52),
                ),
              )
              .toList(),
        ),
        if (row2.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: i < row2.length
                      ? PremiumServiceTile(item: row2[i], iconSize: 52)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class PremiumServiceTile extends StatelessWidget {
  final ExploreFeatureItem item;
  final double iconSize;

  const PremiumServiceTile({
    super.key,
    required this.item,
    this.iconSize = 52,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ScaleTap(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ModernIconBadge(
                  asset: item.iconAsset,
                  icon: item.iconAsset == null ? item.icon : null,
                  gradient: item.gradient,
                  size: iconSize,
                  style: IconBadgeStyle.premiumCircle,
                ),
                if (item.badge != null)
                  Positioned(
                    top: -4,
                    right: 0,
                    child: _FeatureBadge(label: item.badge!, accent: item.gradient.first),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThemeAType.label(size: 13, color: p.textDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const _FeatureBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: ThemeAType.label(size: 9, color: Colors.white).copyWith(letterSpacing: 0.2, height: 1),
      ),
    );
  }
}

/// Backward-compatible alias used by stock_markets_screen.
class ExploreFeatureGrid extends StatelessWidget {
  final List<ExploreFeatureItem> items;

  const ExploreFeatureGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return PremiumExploreCard(
      quickAccess: MarketsExploreShortcuts.quickAccessFrom(items),
      services: MarketsExploreShortcuts.servicesFrom(items),
    );
  }
}

/// Pre-built explore shortcuts for the Markets screen.
class MarketsExploreShortcuts {
  MarketsExploreShortcuts._();

  static List<ExploreFeatureItem> quickAccessFrom(List<ExploreFeatureItem> all) {
    const quickLabels = {'Watchlist', 'Screener', 'News', 'Alerts'};
    return all.where((item) => quickLabels.contains(item.label)).toList();
  }

  static List<ExploreFeatureItem> servicesFrom(List<ExploreFeatureItem> all) {
    const quickLabels = {'Watchlist', 'Screener', 'News', 'Alerts'};
    return all.where((item) => !quickLabels.contains(item.label)).toList();
  }

  static List<ExploreFeatureItem> all({
    required VoidCallback watchlist,
    required VoidCallback screener,
    required VoidCallback news,
    required VoidCallback commodities,
    required VoidCallback alerts,
    required VoidCallback sip,
    required VoidCallback paperTrade,
    required VoidCallback fnoChain,
    required VoidCallback ipoCalendar,
    required VoidCallback investmentNotes,
    required VoidCallback investmentDocuments,
  }) {
    return [
      ExploreFeatureItem(
        icon: Icons.bookmark_rounded,
        iconAsset: AppAssets.featWatchlist,
        label: 'Watchlist',
        gradient: const [Color(0xFF9333EA), Color(0xFFEC4899)],
        onTap: watchlist,
      ),
      ExploreFeatureItem(
        icon: Icons.tune_rounded,
        iconAsset: AppAssets.featScreener,
        label: 'Screener',
        gradient: const [Color(0xFF3B82F6), Color(0xFF22D3EE)],
        onTap: screener,
      ),
      ExploreFeatureItem(
        icon: Icons.newspaper_rounded,
        iconAsset: AppAssets.featNews,
        label: 'News',
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        onTap: news,
      ),
      ExploreFeatureItem(
        icon: Icons.notifications_active_rounded,
        iconAsset: AppAssets.featAlerts,
        label: 'Alerts',
        gradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
        onTap: alerts,
      ),
      ExploreFeatureItem(
        icon: Icons.star_rounded,
        iconAsset: AppAssets.featCommodities,
        label: 'Commodities',
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        onTap: commodities,
      ),
      ExploreFeatureItem(
        icon: Icons.savings_rounded,
        iconAsset: AppAssets.featSip,
        label: 'SIP',
        gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
        onTap: sip,
      ),
      ExploreFeatureItem(
        icon: Icons.show_chart_rounded,
        iconAsset: AppAssets.featPaperTrade,
        label: 'Paper',
        gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        onTap: paperTrade,
      ),
      ExploreFeatureItem(
        icon: Icons.candlestick_chart_rounded,
        iconAsset: AppAssets.featFno,
        label: 'F&O',
        gradient: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
        onTap: fnoChain,
        badge: 'F&O',
      ),
      ExploreFeatureItem(
        icon: Icons.apartment_rounded,
        iconAsset: AppAssets.featIpo,
        label: 'IPO',
        gradient: const [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
        onTap: ipoCalendar,
        badge: 'NEW',
      ),
      ExploreFeatureItem(
        icon: Icons.edit_note_rounded,
        label: 'Journal',
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        onTap: investmentNotes,
        badge: 'NEW',
      ),
      ExploreFeatureItem(
        icon: Icons.folder_special_rounded,
        label: 'Vault',
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        onTap: investmentDocuments,
      ),
    ];
  }
}
