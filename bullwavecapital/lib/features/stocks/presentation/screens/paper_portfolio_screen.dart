import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/paper_portfolio_model.dart';
import '../provider/paper_trading_provider.dart';
import '../widgets/simulation_badge.dart';

/// Unified paper portfolio — every simulated position (stocks, F&O options,
/// commodities) in one place, with live mark-to-market P&L rolled up into
/// a single total. This is the "real profit/loss portfolio" view across the
/// whole paper trading account, not just one asset class at a time.
class PaperPortfolioScreen extends StatefulWidget {
  const PaperPortfolioScreen({super.key});

  @override
  State<PaperPortfolioScreen> createState() => _PaperPortfolioScreenState();
}

class _PaperPortfolioScreenState extends State<PaperPortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperTradingProvider>().loadPortfolio();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Paper Portfolio'),
      body: Consumer<PaperTradingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingPortfolio && provider.portfolio.totalEquity == 0) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 4, itemHeight: 90),
            );
          }
          final p = provider.portfolio;
          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: () => provider.loadPortfolio(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                const SizedBox(height: 14),
                _TotalEquityCard(colors: colors, portfolio: p),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _MiniStat(label: 'Invested', value: CurrencyFormatter.formatDecimal(p.totalInvested), colors: colors)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        label: 'Unrealized P&L',
                        value: CurrencyFormatter.formatDecimal(p.totalUnrealizedPnl),
                        colors: colors,
                        valueColor: p.isProfit ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _AssetClassSection(
                  title: 'Stocks',
                  icon: Icons.show_chart_rounded,
                  color: AppColors.blue,
                  bucket: p.equity,
                  rowBuilder: (h) => _EquityRow(holding: h),
                ),
                const SizedBox(height: 18),
                _AssetClassSection(
                  title: 'F&O Options',
                  icon: Icons.candlestick_chart_rounded,
                  color: AppColors.brandPurple,
                  bucket: p.options,
                  rowBuilder: (h) => _OptionRow(holding: h),
                ),
                const SizedBox(height: 18),
                _AssetClassSection(
                  title: 'Commodities',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.commodityGold,
                  bucket: p.commodities,
                  rowBuilder: (h) => _CommodityRow(holding: h),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TotalEquityCard extends StatelessWidget {
  final AppThemeExtension colors;
  final PaperPortfolioModel portfolio;

  const _TotalEquityCard({required this.colors, required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final isUp = portfolio.totalReturnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total paper equity', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(portfolio.totalEquity),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${portfolio.totalReturnPercent.toStringAsFixed(2)}% vs starting capital',
            style: TextStyle(color: isUp ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Virtual buying power', style: TextStyle(color: colors.textMuted, fontSize: 11.5)),
              Text(CurrencyFormatter.formatDecimal(portfolio.virtualBalance), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Deployed across positions', style: TextStyle(color: colors.textMuted, fontSize: 11.5)),
              Text(CurrencyFormatter.formatDecimal(portfolio.totalCurrentValue), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;
  final Color? valueColor;

  const _MiniStat({required this.label, required this.value, required this.colors, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: valueColor)),
        ],
      ),
    );
  }
}

class _AssetClassSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final PaperPortfolioBucket bucket;
  final Widget Function(Map<String, dynamic>) rowBuilder;

  const _AssetClassSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.bucket,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.textSecondary)),
            const Spacer(),
            if (bucket.count > 0)
              Text(
                '${bucket.isProfit ? '+' : ''}${CurrencyFormatter.formatDecimal(bucket.unrealizedPnl)}',
                style: TextStyle(color: bucket.isProfit ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (bucket.count == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: AppDecorations.card(context),
            child: Center(
              child: Text('No open positions', style: TextStyle(color: colors.textMuted, fontSize: 12.5)),
            ),
          )
        else
          ...bucket.holdings.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: rowBuilder(h),
              )),
      ],
    );
  }
}

class _EquityRow extends StatelessWidget {
  final Map<String, dynamic> holding;

  const _EquityRow({required this.holding});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnl = (holding['pnl'] as num?)?.toDouble() ?? 0;
    final isProfit = pnl >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${holding['symbol'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(
                  '${holding['quantity'] ?? 0} sh • Avg ${IndexFormatter.format((holding['avgPrice'] as num?)?.toDouble() ?? 0)}',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatDecimal((holding['currentValue'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(
                '${isProfit ? '+' : ''}${CurrencyFormatter.formatDecimal(pnl)}',
                style: TextStyle(color: isProfit ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final Map<String, dynamic> holding;

  const _OptionRow({required this.holding});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnl = (holding['unrealizedPnlInr'] as num?)?.toDouble() ?? 0;
    final hasLive = holding['ltpPremium'] != null;
    final isProfit = pnl >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${holding['contractLabel'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(
                  '${holding['quantity'] ?? 0} lot(s) • Avg ${IndexFormatter.format((holding['avgPremium'] as num?)?.toDouble() ?? 0)}',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasLive ? CurrencyFormatter.formatDecimal((holding['currentValueInr'] as num?)?.toDouble() ?? 0) : '—',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              Text(
                hasLive ? '${isProfit ? '+' : ''}${CurrencyFormatter.formatDecimal(pnl)}' : 'live price unavailable',
                style: TextStyle(color: hasLive ? (isProfit ? AppColors.green : AppColors.red) : colors.textMuted, fontWeight: FontWeight.w700, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommodityRow extends StatelessWidget {
  final Map<String, dynamic> holding;

  const _CommodityRow({required this.holding});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnl = (holding['pnlInr'] as num?)?.toDouble() ?? 0;
    final isProfit = pnl >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${holding['shortName'] ?? holding['commodityId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(
                  '${holding['quantity'] ?? 0} units • Avg \$${IndexFormatter.format((holding['avgPriceUsd'] as num?)?.toDouble() ?? 0)}',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatDecimal((holding['currentValueInr'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(
                '${isProfit ? '+' : ''}${CurrencyFormatter.formatDecimal(pnl)}',
                style: TextStyle(color: isProfit ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
