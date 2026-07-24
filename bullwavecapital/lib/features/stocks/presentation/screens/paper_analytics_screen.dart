import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/robinhood_line_chart.dart';
import '../provider/paper_trading_provider.dart';
import '../widgets/simulation_badge.dart';

/// Performance analytics — win rate, profit factor, drawdown, equity curve.
class PaperAnalyticsScreen extends StatefulWidget {
  const PaperAnalyticsScreen({super.key});

  @override
  State<PaperAnalyticsScreen> createState() => _PaperAnalyticsScreenState();
}

class _PaperAnalyticsScreenState extends State<PaperAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperTradingProvider>().loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Performance Analytics'),
      body: Consumer<PaperTradingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingAnalytics && provider.analytics.totalTrades == 0) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 4, itemHeight: 90),
            );
          }
          final a = provider.analytics;
          final curveValues = a.equityCurve.map((p) => p.equity).toList();
          final isUp = a.totalReturnPercent >= 0;

          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: () => context.read<PaperTradingProvider>().loadAnalytics(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Equity', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(a.currentEquity),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isUp ? '+' : ''}${a.totalReturnPercent.toStringAsFixed(2)}% vs starting capital',
                        style: TextStyle(
                          color: isUp ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (curveValues.length >= 2)
                        RobinhoodLineChart(values: curveValues, isPositive: isUp, height: 110)
                      else
                        SizedBox(
                          height: 60,
                          child: Center(
                            child: Text('Trade a bit more to see your equity curve.',
                                style: TextStyle(color: colors.textMuted, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: [
                    _StatTile(label: 'Win Rate', value: '${a.winRatePercent.toStringAsFixed(1)}%', color: AppColors.green),
                    _StatTile(label: 'Profit Factor', value: a.profitFactor.toStringAsFixed(2), color: AppColors.blue),
                    _StatTile(
                      label: 'Max Drawdown',
                      value: '${a.maxDrawdownPercent.toStringAsFixed(1)}%',
                      color: AppColors.red,
                    ),
                    _StatTile(label: 'Total Trades', value: '${a.totalTrades}', color: AppColors.brandPurple),
                    _StatTile(
                      label: 'Best Trade',
                      value: CurrencyFormatter.formatCompact(a.bestTrade),
                      color: AppColors.green,
                    ),
                    _StatTile(
                      label: 'Worst Trade',
                      value: CurrencyFormatter.formatCompact(a.worstTrade),
                      color: AppColors.red,
                    ),
                    _StatTile(label: 'Avg Win', value: CurrencyFormatter.formatCompact(a.avgWin), color: AppColors.green),
                    _StatTile(label: 'Avg Loss', value: CurrencyFormatter.formatCompact(a.avgLoss), color: AppColors.red),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trade Breakdown', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary)),
                      const SizedBox(height: 10),
                      _BreakdownRow(label: 'Closed trades', value: '${a.closedTrades}'),
                      _BreakdownRow(label: 'Wins', value: '${a.winCount}', color: AppColors.green),
                      _BreakdownRow(label: 'Losses', value: '${a.lossCount}', color: AppColors.red),
                      _BreakdownRow(
                        label: 'Total realized P&L',
                        value: CurrencyFormatter.format(a.totalRealizedPnl),
                        color: a.totalRealizedPnl >= 0 ? AppColors.green : AppColors.red,
                      ),
                      _BreakdownRow(label: 'Max drawdown (₹)', value: CurrencyFormatter.format(a.maxDrawdownAmount)),
                    ],
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _BreakdownRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
