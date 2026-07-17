import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ai_assistant_fab.dart';
import '../../../../core/widgets/app_screen_background.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../../../../models/commodity_model.dart';
import '../provider/commodity_provider.dart';

class CommodityMarketScreen extends StatefulWidget {
  const CommodityMarketScreen({super.key});

  @override
  State<CommodityMarketScreen> createState() => _CommodityMarketScreenState();
}

class _CommodityMarketScreenState extends State<CommodityMarketScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommodityProvider>().ensureLoaded();
    });
  }

  Color _accentFor(String category) {
    switch (category) {
      case 'Precious Metals':
        return AppColors.commodityGold;
      case 'Energy':
        return AppColors.commodityEnergy;
      case 'Industrial Metals':
        return AppColors.commodityMetal;
      default:
        return AppColors.brandOrange;
    }
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'gold':
        return Icons.monetization_on_rounded;
      case 'silver':
        return Icons.diamond_outlined;
      case 'oil':
        return Icons.local_gas_station_outlined;
      case 'gas':
        return Icons.whatshot_outlined;
      case 'copper':
      case 'metal':
        return Icons.construction_outlined;
      case 'platinum':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppScreenBackground(
        child: Stack(
          children: [
            Column(
              children: [
                const CustomAppBar(title: 'Commodities', showBack: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickLink(
                          icon: Icons.candlestick_chart_rounded,
                          label: 'Option Chain',
                          color: AppColors.brandPurple,
                          onTap: () => context.push(
                            '${AppRoutes.commodityOptionChain}?commodityId=GOLD',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Consumer<CommodityProvider>(
                          builder: (context, p, _) => _QuickLink(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Holdings',
                            color: AppColors.green,
                            badge: p.holdings.isNotEmpty ? '${p.holdings.length}' : null,
                            onTap: () => context.push(
                              '${AppRoutes.commodityDetail}?commodityId=GOLD',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<CommodityProvider>(
                    builder: (context, commodities, _) {
                      if (commodities.isLoading && commodities.commodities.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.brandOrange),
                        );
                      }

                      final rows = commodities.commodities;
                      if (rows.isEmpty) {
                        return RefreshIndicator(
                          color: AppColors.brandOrange,
                          onRefresh: commodities.refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  commodities.error ?? 'No commodity data. Pull to refresh.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: AppColors.brandOrange,
                        onRefresh: commodities.refresh,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            _HeroBanner(provider: commodities.provider),
                            if (commodities.isUsingDemoData) ...[
                              const SizedBox(height: 12),
                              const PremiumAlertBanner(
                                message:
                                    'Demo commodity prices shown. Start Django backend for live Yahoo Finance quotes.',
                                type: PremiumAlertType.info,
                              ),
                            ],
                            const SizedBox(height: 20),
                            ...commodities.categories.map((category) {
                              final items = commodities.commoditiesByCategory(category);
                              final accent = _accentFor(category);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          category,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...items.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _CommodityCard(
                                          commodity: item,
                                          accent: accent,
                                          icon: _iconFor(item.icon),
                                          onTap: () => context.push(
                                            '${AppRoutes.commodityDetail}?commodityId=${item.id}',
                                          ),
                                          onOptions: () => context.push(
                                            '${AppRoutes.commodityOptionChain}?commodityId=${item.id}',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const AiAssistantFab(bottom: 24),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String provider;

  const _HeroBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(context, premium: true, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.green),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
              if (provider.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  provider.toUpperCase(),
                  style: TextStyle(color: context.appColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Global Commodity Markets',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Trade spot & explore options on gold, silver, oil & more',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: AppDecorations.premiumTile(context, accent: color),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge!, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommodityCard extends StatelessWidget {
  final CommodityModel commodity;
  final Color accent;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onOptions;

  const _CommodityCard({
    required this.commodity,
    required this.accent,
    required this.icon,
    this.onTap,
    this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final changeColor = commodity.isPositive ? AppColors.green : AppColors.red;

    return RobinhoodCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      glow: commodity.isPositive,
      glowColor: changeColor,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commodity.shortName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                ),
                Text(commodity.unit, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${IndexFormatter.format(commodity.ltp)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                IndexFormatter.formatPercent(commodity.changePercent),
                style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onOptions,
            icon: Icon(Icons.candlestick_chart_rounded, color: AppColors.brandPurple, size: 22),
            tooltip: 'Option chain',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brandPurple.withValues(alpha: 0.12),
              minimumSize: const Size(40, 40),
            ),
          ),
        ],
      ),
    );
  }
}
