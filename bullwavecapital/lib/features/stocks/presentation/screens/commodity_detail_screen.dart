import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ai_assistant_fab.dart';
import '../../../../core/widgets/app_screen_background.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../../../../models/commodity_model.dart';
import '../provider/commodity_provider.dart';
import '../utils/commodity_trading_flow.dart';
import '../widgets/chart_interval_selector.dart';
import '../widgets/stock_detail_chart.dart';

class CommodityDetailScreen extends StatefulWidget {
  final String commodityId;

  const CommodityDetailScreen({super.key, required this.commodityId});

  @override
  State<CommodityDetailScreen> createState() => _CommodityDetailScreenState();
}

class _CommodityDetailScreenState extends State<CommodityDetailScreen> {
  String _intervalLabel = '1D';

  String get _apiInterval {
    for (final item in stockChartIntervals) {
      if (item.label == _intervalLabel) return item.apiInterval;
    }
    return '1d';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CommodityProvider>();
      provider.loadDetail(widget.commodityId);
      provider.loadHoldings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppScreenBackground(
        child: Stack(
          children: [
            Consumer<CommodityProvider>(
              builder: (context, provider, _) {
                final commodity = provider.commodityById(widget.commodityId);
                if (commodity == null && provider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.brandOrange));
                }
                if (commodity == null) {
                  return const Center(child: Text('Commodity not found'));
                }

                final holding = provider.holdingFor(commodity.id);
                final changeColor = commodity.isPositive ? AppColors.green : AppColors.red;

                return Column(
                  children: [
                    CustomAppBar(
                      title: commodity.shortName,
                      subtitle: commodity.category,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        children: [
                          _PriceHero(commodity: commodity, changeColor: changeColor),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: TradingViewChart(
                              symbol: commodity.id,
                              intervalLabel: _intervalLabel,
                              apiInterval: _apiInterval,
                              isCommodity: true,
                              height: 280,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ChartIntervalSelector(
                            selectedLabel: _intervalLabel,
                            onSelected: (label) => setState(() => _intervalLabel = label),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionChip(
                                  icon: Icons.candlestick_chart_rounded,
                                  label: 'Option Chain',
                                  color: AppColors.brandPurple,
                                  onTap: () => context.push(
                                    '${AppRoutes.commodityOptionChain}?commodityId=${commodity.id}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ActionChip(
                                  icon: Icons.show_chart_rounded,
                                  label: 'Live Chart',
                                  color: AppColors.blue,
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Day High',
                                  value: '\$${IndexFormatter.format(commodity.high)}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  label: 'Day Low',
                                  value: '\$${IndexFormatter.format(commodity.low)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _StatCard(
                            label: 'Previous Close',
                            value: '\$${IndexFormatter.format(commodity.previousClose)}',
                          ),
                          if (holding != null) ...[
                            const SizedBox(height: 22),
                            Text(
                              'Your Position',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            RobinhoodCard(
                              glow: holding.isProfit,
                              glowColor: holding.isProfit ? AppColors.green : AppColors.red,
                              child: Column(
                                children: [
                                  _HoldingRow(label: 'Units held', value: '${holding.quantity}'),
                                  _HoldingRow(
                                    label: 'Avg buy price',
                                    value: '\$${IndexFormatter.format(holding.avgPriceUsd)}',
                                  ),
                                  _HoldingRow(
                                    label: 'Invested (INR)',
                                    value: CurrencyFormatter.formatDecimal(holding.investedInr),
                                  ),
                                  _HoldingRow(
                                    label: 'Current value',
                                    value: CurrencyFormatter.formatDecimal(holding.currentValueInr),
                                  ),
                                  _HoldingRow(
                                    label: 'P&L',
                                    value:
                                        '${holding.pnlInr >= 0 ? '+' : ''}${CurrencyFormatter.formatDecimal(holding.pnlInr)} (${holding.pnlPercent.toStringAsFixed(2)}%)',
                                    valueColor: holding.isProfit ? AppColors.green : AppColors.red,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _TradeBar(commodity: commodity),
                  ],
                );
              },
            ),
            const AiAssistantFab(bottom: 88),
          ],
        ),
      ),
    );
  }
}

class _PriceHero extends StatelessWidget {
  final CommodityModel commodity;
  final Color changeColor;

  const _PriceHero({required this.commodity, required this.changeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card(context, premium: true, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(commodity.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '\$${IndexFormatter.format(commodity.ltp)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 38, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                commodity.isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 18,
                color: changeColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${IndexFormatter.formatChange(commodity.change)} (${IndexFormatter.formatPercent(commodity.changePercent)})',
                style: TextStyle(color: changeColor, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(commodity.unit, style: TextStyle(color: context.appColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RobinhoodCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _HoldingRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

class _TradeBar extends StatelessWidget {
  final CommodityModel commodity;

  const _TradeBar({required this.commodity});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final holdingQty = context.watch<CommodityProvider>().holdingQtyFor(commodity.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => openCommodityTradingPad(context, commodity: commodity, initialSide: 'BUY'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: holdingQty < 1
                    ? null
                    : () => openCommodityTradingPad(context, commodity: commodity, initialSide: 'SELL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Sell', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
