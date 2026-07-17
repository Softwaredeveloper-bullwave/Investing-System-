import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/assets.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/modern_icon_badge.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../fno/fno_navigation.dart';
import 'explore_feature_tile.dart';

class MarketsQuickActions extends StatelessWidget {
  final VoidCallback onMore;

  const MarketsQuickActions({
    super.key,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final actions = [
      _QuickAction(
        label: 'Watchlist',
        iconAsset: AppAssets.featWatchlist,
        icon: Icons.bookmark_rounded,
        gradient: const [Color(0xFF9333EA), Color(0xFFEC4899)],
        onTap: () => context.push(AppRoutes.watchlist),
      ),
      _QuickAction(
        label: 'Screener',
        iconAsset: AppAssets.featScreener,
        icon: Icons.tune_rounded,
        gradient: const [Color(0xFF3B82F6), Color(0xFF22D3EE)],
        onTap: () => context.push(AppRoutes.stockScreener),
      ),
      _QuickAction(
        label: 'Copy Trade',
        icon: Icons.people_alt_rounded,
        gradient: const [Color(0xFF059669), Color(0xFF34D399)],
        onTap: () => context.push(AppRoutes.copyTrading),
      ),
      _QuickAction(
        label: 'Paper Trading',
        iconAsset: AppAssets.featPaperTrade,
        icon: Icons.show_chart_rounded,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        onTap: () => openFnoFeature(context, AppRoutes.paperTrading),
      ),
      _QuickAction(
        label: 'More',
        icon: Icons.apps_rounded,
        gradient: [p.primarySoft, p.primary],
        onTap: onMore,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          children: actions
              .map(
                (a) => Expanded(
                  child: ScaleTap(
                    onTap: a.onTap,
                    child: Column(
                      children: [
                        ModernIconBadge(
                          asset: a.iconAsset,
                          icon: a.iconAsset == null ? a.icon : null,
                          gradient: a.gradient,
                          size: 48,
                          style: IconBadgeStyle.premiumCircle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThemeAType.label(size: 11, color: p.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String? iconAsset;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    this.iconAsset,
    required this.gradient,
    required this.onTap,
  });
}

void showMarketsMoreSheet(
  BuildContext context, {
  required List<ExploreFeatureItem> overflowItems,
}) {
  final p = context.palette;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.borderLight),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('More tools', style: ThemeAType.sectionTitle(color: p.textDark)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: overflowItems
                      .map(
                        (item) => SizedBox(
                          width: (MediaQuery.sizeOf(ctx).width - 64) / 4,
                          child: PremiumServiceTile(item: item, iconSize: 48),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

List<ExploreFeatureItem> marketsOverflowShortcuts({
  required VoidCallback news,
  required VoidCallback commodities,
  required VoidCallback alerts,
  required VoidCallback sip,
  required VoidCallback fnoChain,
  required VoidCallback ipoCalendar,
  required VoidCallback blockDeals,
  required VoidCallback darkPool,
  required VoidCallback copyTrading,
  required VoidCallback heatMap,
  required VoidCallback investmentJournal,
  required VoidCallback researchVault,
  required VoidCallback academy,
  required VoidCallback calculator,
  required VoidCallback leaderboard,
  required VoidCallback moodDetector,
}) {
  return [
    ExploreFeatureItem(
      icon: Icons.people_alt_rounded,
      label: 'Copy Trade',
      gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
      onTap: copyTrading,
    ),
    ExploreFeatureItem(
      icon: Icons.grid_view_rounded,
      label: 'Heat Map',
      gradient: const [Color(0xFF059669), Color(0xFF6EE7B7)],
      onTap: heatMap,
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
    ),
    ExploreFeatureItem(
      icon: Icons.handshake_rounded,
      label: 'Block Deals',
      gradient: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
      onTap: blockDeals,
    ),
    ExploreFeatureItem(
      icon: Icons.water_drop_rounded,
      label: 'Dark Pool',
      gradient: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      onTap: darkPool,
    ),
    ExploreFeatureItem(
      icon: Icons.edit_note_rounded,
      label: 'Journal',
      gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
      onTap: investmentJournal,
    ),
    ExploreFeatureItem(
      icon: Icons.folder_special_rounded,
      label: 'Vault',
      gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      onTap: researchVault,
    ),
    ExploreFeatureItem(
      icon: Icons.school_rounded,
      label: 'Academy',
      gradient: const [Color(0xFF3B82F6), Color(0xFF22D3EE)],
      onTap: academy,
    ),
    ExploreFeatureItem(
      icon: Icons.calculate_rounded,
      label: 'Calculator',
      gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
      onTap: calculator,
    ),
    ExploreFeatureItem(
      icon: Icons.leaderboard_rounded,
      label: 'Leaderboard',
      gradient: const [Color(0xFFCA8A04), Color(0xFFFBBF24)],
      onTap: leaderboard,
    ),
    ExploreFeatureItem(
      icon: Icons.psychology_alt_rounded,
      label: 'Mood AI',
      gradient: const [Color(0xFF9333EA), Color(0xFFEC4899)],
      onTap: moodDetector,
    ),
  ];
}

/// Anchor key for heat map scroll target from quick actions.
class MarketsHeatMapSectionAnchor {
  MarketsHeatMapSectionAnchor._();
  static final globalKey = GlobalKey();
}
