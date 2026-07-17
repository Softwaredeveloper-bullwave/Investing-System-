import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/kyc_completion_banner.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/portfolio_card.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../models/transaction_model.dart';
import '../../../transactions/presentation/provider/transaction_provider.dart';
import '../../../stocks/presentation/provider/stock_portfolio_provider.dart';
import '../../../stocks/presentation/utils/stock_trading_flow.dart';
import '../provider/portfolio_provider.dart';
import '../../../stocks/presentation/widgets/stock_order_history_tile.dart';
import '../widgets/portfolio_holding_tile.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StockPortfolioProvider>().ensureLoaded(refreshQuotes: false);
    });
  }

  Future<void> _reload({bool refreshQuotes = false}) async {
    await Future.wait([
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: refreshQuotes),
      context.read<PortfolioProvider>().loadData(),
      context.read<TransactionProvider>().loadData(),
    ]);
  }

  Future<void> _refreshPrices() => _reload(refreshQuotes: true);

  @override
  Widget build(BuildContext context) {
    return Consumer2<StockPortfolioProvider, PortfolioProvider>(
      builder: (context, stockPortfolio, planPortfolio, _) {
        if (stockPortfolio.isLoading && stockPortfolio.holdings.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: LoadingList(itemCount: 4),
            ),
          );
        }

        final summary = stockPortfolio.summary;
        final hasHoldings = stockPortfolio.holdings.isNotEmpty;
        final hasPlans = planPortfolio.allocations.isNotEmpty;

        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.brandCyan,
            onRefresh: _refreshPrices,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShellPageHeader(
                    title: 'Portfolio',
                    subtitle: stockPortfolio.holdingsCount > 0
                        ? '${stockPortfolio.holdingsCount} active holdings'
                        : 'Track stocks & goal plans',
                    trailing: stockPortfolio.holdingsCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${stockPortfolio.holdingsCount} stocks',
                              style: const TextStyle(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  const KycCompletionBanner(),
                  const SizedBox(height: 8),
                  if (stockPortfolio.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PremiumAlertBanner(
                        message: stockPortfolio.error!,
                        type: PremiumAlertType.error,
                        actionLabel: 'Retry',
                        onAction: () => _reload(),
                      ),
                    ),
                  PortfolioSummaryCard(
                    totalInvestment: summary.totalInvested,
                    currentValue: summary.currentValue,
                    totalProfit: summary.totalPnl,
                    todayPnl: summary.dayPnl,
                    todayPnlPercent: summary.dayPnlPercent,
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Holdings',
                    actionLabel: hasHoldings ? 'Analytics' : null,
                    onAction: hasHoldings ? () => context.push(AppRoutes.portfolioAnalytics) : null,
                  ),
                  const SizedBox(height: AppDimensions.paddingSm),
                  if (!hasHoldings)
                    GlassCard(
                      radius: 24,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.brandPrimary.withValues(alpha: 0.3),
                                  AppColors.brandPrimary.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(color: AppColors.brandPrimaryLight.withValues(alpha: 0.35)),
                            ),
                            child: const Icon(Icons.pie_chart_outline_rounded, size: 36, color: AppColors.brandPrimaryLight),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No stock holdings yet',
                            style: context.typeSection(17),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Buy stocks from Markets or try Paper Trading to build your portfolio.',
                            textAlign: TextAlign.center,
                            style: context.typeSecondary(14),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: GradientActionButton(
                                  label: 'Markets',
                                  outlined: true,
                                  onTap: () => context.go(AppRoutes.invest),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GradientActionButton(
                                  label: 'Paper Trade',
                                  onTap: () => context.push(AppRoutes.paperTrading),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    ...stockPortfolio.holdings.map(
                      (h) => PortfolioHoldingTile(
                        holding: h,
                        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${h.symbol}'),
                        onBuy: () => executeStockTrade(
                          context,
                          stock: h.toTradeStock(),
                          side: 'BUY',
                        ),
                        onSell: () => executeStockTrade(
                          context,
                          stock: h.toTradeStock(),
                          side: 'SELL',
                        ),
                      ),
                    ),
                  if (stockPortfolio.recentTrades.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingLg),
                    SectionHeader(
                      title: 'Recent Orders',
                      actionLabel: 'All',
                      onAction: () => context.push(AppRoutes.paperTrading),
                    ),
                    const SizedBox(height: AppDimensions.paddingSm),
                    ...stockPortfolio.recentTrades.take(5).map(
                          (order) => StockOrderHistoryTile(
                            order: order,
                            onTap: () => context.push(
                              '${AppRoutes.stockDetail}?symbol=${order.symbol}',
                            ),
                          ),
                        ),
                  ],
                  if (hasHoldings && stockPortfolio.sectorAllocation.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingLg),
                    SectionHeader(title: 'Sector Allocation'),
                    const SizedBox(height: AppDimensions.paddingSm),
                    ...stockPortfolio.sectorAllocation.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RobinhoodCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${CurrencyFormatter.formatCompact(item.value)} • ${item.percentage.toStringAsFixed(1)}%',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: item.percentage / 100,
                                  minHeight: 6,
                                  backgroundColor: AppColors.border,
                                  color: Color(item.colorValue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.paddingMd),
                  Row(
                    children: [
                      Expanded(
                        child: GradientActionButton(
                          label: 'Dividends',
                          outlined: true,
                          onTap: () => context.push(AppRoutes.dividendTracker),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientActionButton(
                          label: 'SIP Tracker',
                          outlined: true,
                          onTap: () => context.push(AppRoutes.sipTracker),
                        ),
                      ),
                    ],
                  ),
                  if (hasPlans) ...[
                    const SizedBox(height: AppDimensions.paddingLg),
                    SectionHeader(title: 'Investment Plans'),
                    const SizedBox(height: AppDimensions.paddingSm),
                    ...planPortfolio.allocations.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RobinhoodCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Allocation', style: Theme.of(context).textTheme.bodySmall),
                                  Text('${item.percentage}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: item.percentage / 100,
                                  minHeight: 6,
                                  backgroundColor: AppColors.border,
                                  color: Color(item.colorValue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.paddingLg),
                  Consumer<TransactionProvider>(
                    builder: (context, txProvider, _) {
                      final recent = txProvider.allTransactions.take(3).toList();
                      if (recent.isEmpty) return SizedBox(height: ShellLayout.contentBottomInset);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: 'Recent Activity'),
                          const SizedBox(height: AppDimensions.paddingSm),
                          ...recent.map(
                            (txn) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RobinhoodCard(
                                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(txn.description, style: Theme.of(context).textTheme.titleMedium),
                                          Text(
                                            CurrencyFormatter.format(txn.amount),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      txn.type.name.toUpperCase(),
                                      style: TextStyle(
                                        color: txn.type == TransactionType.profit ? AppColors.green : AppColors.red,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: ShellLayout.contentBottomInset),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
