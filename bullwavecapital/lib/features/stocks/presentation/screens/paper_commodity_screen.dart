import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/commodity_model.dart';
import '../provider/commodity_provider.dart';
import '../provider/paper_trading_provider.dart';
import '../widgets/paper_commodity_trading_pad.dart';
import '../widgets/simulation_badge.dart';

/// Paper-trading twin of [CommodityMarketScreen] — same live commodity
/// quotes (reuses [CommodityProvider], the same market-data feed as real
/// commodity trading) but tapping a commodity opens
/// [PaperCommodityTradingPad] so every order is simulated only.
class PaperCommodityScreen extends StatefulWidget {
  const PaperCommodityScreen({super.key});

  @override
  State<PaperCommodityScreen> createState() => _PaperCommodityScreenState();
}

class _PaperCommodityScreenState extends State<PaperCommodityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommodityProvider>().ensureLoaded();
      context.read<PaperTradingProvider>().loadCommodityOrders();
    });
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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Paper Commodities'),
      body: Consumer2<CommodityProvider, PaperTradingProvider>(
        builder: (context, commodities, trading, _) {
          if (commodities.isLoading && commodities.commodities.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 5, itemHeight: 72),
            );
          }
          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: () => commodities.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                const SizedBox(height: 14),
                if (trading.commodityHoldings.isNotEmpty) ...[
                  Text('Your paper positions', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...trading.commodityHoldings.map((h) => _PaperHoldingCard(holding: h)),
                  const SizedBox(height: 18),
                ],
                Text('Market', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                ...commodities.commodities.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CommodityRow(
                      commodity: c,
                      icon: _iconFor(c.icon),
                      onTap: () => PaperCommodityTradingPad.show(context, commodity: c),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommodityRow extends StatelessWidget {
  final CommodityModel commodity;
  final IconData icon;
  final VoidCallback onTap;

  const _CommodityRow({required this.commodity, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.card(context),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.brandOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.brandOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commodity.shortName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(commodity.unit, style: TextStyle(color: colors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${IndexFormatter.format(commodity.ltp)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    IndexFormatter.formatPercent(commodity.changePercent),
                    style: TextStyle(color: commodity.isPositive ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperHoldingCard extends StatelessWidget {
  final CommodityHoldingModel holding;

  const _PaperHoldingCard({required this.holding});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(holding.shortName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text('${holding.quantity} units • Avg \$${IndexFormatter.format(holding.avgPriceUsd)}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatDecimal(holding.currentValueInr), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(
                '${holding.isProfit ? '+' : ''}${CurrencyFormatter.formatDecimal(holding.pnlInr)}',
                style: TextStyle(color: holding.isProfit ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
