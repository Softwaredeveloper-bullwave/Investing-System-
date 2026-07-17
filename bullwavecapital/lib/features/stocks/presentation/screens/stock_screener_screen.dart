import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';

class StockScreenerScreen extends StatelessWidget {
  const StockScreenerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Stock Screener'),
      body: Consumer<StockFeaturesProvider>(
        builder: (context, features, _) {
          if (features.isScreenerLoading && features.screenerResults.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.green));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: AppColors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Live Nifty 50 • ${context.watch<StockMarketProvider>().marketProvider.isNotEmpty ? context.watch<StockMarketProvider>().marketProvider : 'Alpha Vantage'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: features.sectors.map((s) {
                    final selected = features.screenerSector == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (_) => features.setScreenerSector(s),
                        selectedColor: AppColors.green.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.green,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.green,
                  onRefresh: features.refreshScreener,
                  child: features.screenerResults.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No stocks match filters')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: features.screenerResults.length,
                          itemBuilder: (_, i) {
                            final item = features.screenerResults[i];
                            final stock = item.stock;
                            final changeColor =
                                stock.changePercent >= 0 ? AppColors.green : AppColors.red;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RobinhoodCard(
                                onTap: () => context.push(
                                  '${AppRoutes.stockDetail}?symbol=${stock.symbol}',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            stock.symbol,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        Text(
                                          IndexFormatter.format(stock.ltp),
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                    Text(stock.name, style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                                      style: TextStyle(color: changeColor, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _Metric('PE', stock.pe > 0 ? stock.pe.toStringAsFixed(1) : '—'),
                                        _Metric('ROE', '${item.roe.toStringAsFixed(1)}%'),
                                        _Metric('D/E', item.debtToEquity.toStringAsFixed(2)),
                                        _Metric('Growth', '${item.revenueGrowth.toStringAsFixed(0)}%'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ],
    );
  }
}
