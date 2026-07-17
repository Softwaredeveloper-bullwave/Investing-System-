import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../../../../models/portfolio_health_model.dart';
import '../../../portfolio/presentation/widgets/portfolio_holding_tile.dart';
import '../provider/stock_portfolio_provider.dart';
import '../widgets/portfolio_health_score_card.dart';
import '../widgets/paper_competition_widgets.dart';

class PortfolioAnalyticsScreen extends StatefulWidget {
  const PortfolioAnalyticsScreen({super.key});

  @override
  State<PortfolioAnalyticsScreen> createState() => _PortfolioAnalyticsScreenState();
}

class _PortfolioAnalyticsScreenState extends State<PortfolioAnalyticsScreen> {
  PortfolioHealthModel? _health;
  bool _healthLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockPortfolioProvider>().loadPortfolio();
      context.read<StockPortfolioProvider>().loadMarketRiskMeter();
      _loadHealth();
    });
  }

  Future<void> _loadHealth() async {
    setState(() => _healthLoading = true);
    try {
      final health = await BullwaveApi.instance.getPortfolioHealth();
      if (mounted) setState(() => _health = health);
    } catch (_) {
      if (mounted) setState(() => _health = null);
    }
    if (mounted) setState(() => _healthLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Portfolio Analytics'),
      body: Consumer<StockPortfolioProvider>(
        builder: (context, portfolio, _) {
          if (portfolio.isLoading && portfolio.holdings.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandOrange));
          }

          final summary = portfolio.summary;
          final sectors = portfolio.sectorAllocation;

          return RefreshIndicator(
            onRefresh: () async {
              await portfolio.loadPortfolio(refreshQuotes: true);
              await portfolio.loadMarketRiskMeter();
              await _loadHealth();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PortfolioHealthScoreCard(
                  health: _health,
                  isLoading: _healthLoading,
                  onRefresh: _loadHealth,
                ),
                const SizedBox(height: 12),
                PaperRiskMeterCard(
                  meter: portfolio.marketRiskMeter,
                  isLoading: portfolio.riskLoading,
                  title: 'Market Risk Meter',
                ),
                const SizedBox(height: 16),
                RobinhoodCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Portfolio Summary',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _Row('Invested', CurrencyFormatter.format(summary.totalInvested)),
                      _Row('Current Value', CurrencyFormatter.format(summary.currentValue)),
                      _Row(
                        'Total P&L',
                        CurrencyFormatter.format(summary.totalPnl),
                        color: summary.totalPnl >= 0 ? AppColors.green : AppColors.red,
                      ),
                      _Row('Return', '${summary.totalPnlPercent.toStringAsFixed(2)}%'),
                      _Row(
                        'Today',
                        CurrencyFormatter.format(summary.dayPnl),
                        color: summary.dayPnl >= 0 ? AppColors.green : AppColors.red,
                      ),
                      _Row('Holdings', '${summary.holdingsCount}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.priceAlerts),
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Price & News Alerts'),
                ),
                const SizedBox(height: 16),
                if (sectors.isNotEmpty) ...[
                  Text(
                    'Sector Allocation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...sectors.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RobinhoodCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${item.percentage.toStringAsFixed(1)}%'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(item.value),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: item.percentage / 100,
                              color: Color(item.colorValue),
                              backgroundColor: AppColors.border,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                Text(
                  'All Holdings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (portfolio.holdings.isEmpty)
                  const RobinhoodCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No holdings to analyze yet.'),
                    ),
                  )
                else
                  ...portfolio.holdings.map(
                    (h) => PortfolioHoldingTile(
                      holding: h,
                      onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${h.symbol}'),
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Row(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
