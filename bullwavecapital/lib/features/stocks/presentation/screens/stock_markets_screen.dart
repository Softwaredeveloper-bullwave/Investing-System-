import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/kyc_completion_banner.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../fno/fno_navigation.dart';
import '../../../home/presentation/provider/home_provider.dart';
import '../provider/stock_market_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import '../widgets/markets_economic_calendar.dart';
import '../widgets/markets_fno_indices.dart';
import '../widgets/market_heat_map.dart';
import '../widgets/markets_learning_hub.dart';
import '../widgets/markets_news_section.dart';
import '../widgets/markets_portfolio_summary.dart';
import '../widgets/markets_premium_overview.dart';
import '../widgets/markets_quick_actions.dart';
import '../widgets/markets_sticky_search.dart';
import '../widgets/markets_today_events.dart';
import '../widgets/markets_top_movers.dart';
import '../widgets/markets_voice_search_sheet.dart';
import '../widgets/markets_watchlist_preview.dart';
import '../widgets/paper_competition_widgets.dart';
import '../widgets/stock_list_tile.dart';

class StockMarketsScreen extends StatefulWidget {
  const StockMarketsScreen({super.key});

  @override
  State<StockMarketsScreen> createState() => _StockMarketsScreenState();
}

class _StockMarketsScreenState extends State<StockMarketsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMarketProvider>().ensureLoaded();
      context.read<HomeProvider>().loadData();
      context.read<StockPortfolioProvider>().ensureLoaded();
      context.read<StockPortfolioProvider>().loadMarketRiskMeter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToHeatMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = MarketsHeatMapSectionAnchor.globalKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
  }

  void _openEconomicCalendar() {
    context.push(AppRoutes.economicCalendar);
  }

  Future<void> _openVoiceSearch() async {
    final spoken = await showMarketsVoiceSearchSheet(context);
    if (!mounted || spoken == null || spoken.trim().isEmpty) return;
    final query = spoken.trim();
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    context.read<StockMarketProvider>().setSearchQuery(query);
  }

  void _showMoreSheet(BuildContext context) {
    showMarketsMoreSheet(
      context,
      overflowItems: marketsOverflowShortcuts(
        news: () {
          Navigator.pop(context);
          context.push(AppRoutes.stockNews);
        },
        commodities: () {
          Navigator.pop(context);
          context.push(AppRoutes.commodities);
        },
        alerts: () {
          Navigator.pop(context);
          context.push(AppRoutes.priceAlerts);
        },
        sip: () {
          Navigator.pop(context);
          context.push(AppRoutes.sipTracker);
        },
        fnoChain: () {
          Navigator.pop(context);
          openFnoFeature(context, AppRoutes.optionChain);
        },
        ipoCalendar: () {
          Navigator.pop(context);
          context.push(AppRoutes.ipoCalendar);
        },
        blockDeals: () {
          Navigator.pop(context);
          context.push(AppRoutes.blockDealTracker);
        },
        darkPool: () {
          Navigator.pop(context);
          context.push(AppRoutes.darkPoolTracker);
        },
        copyTrading: () {
          Navigator.pop(context);
          context.push(AppRoutes.copyTrading);
        },
        heatMap: () {
          Navigator.pop(context);
          _scrollToHeatMap();
        },
        investmentJournal: () {
          Navigator.pop(context);
          context.push(AppRoutes.investmentNotes);
        },
        researchVault: () {
          Navigator.pop(context);
          context.push(AppRoutes.investmentDocuments);
        },
        academy: () {
          Navigator.pop(context);
          context.push(AppRoutes.documentCategoryPath('beginner'));
        },
        calculator: () {
          Navigator.pop(context);
          context.push(AppRoutes.investmentCalculator);
        },
        leaderboard: () {
          Navigator.pop(context);
          context.push(AppRoutes.leaderboard);
        },
        moodDetector: () {
          Navigator.pop(context);
          context.push(AppRoutes.moodDetector);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StockMarketProvider, HomeProvider>(
      builder: (context, market, home, _) {
        final searching = market.searchQuery.isNotEmpty;
        final stocks = searching ? market.searchResults : market.trendingStocks;
        final portfolio = context.watch<StockPortfolioProvider>();

        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.brandCyan,
            onRefresh: () async {
              await Future.wait([
                market.refresh(),
                home.refresh(),
                portfolio.loadPortfolio(refreshQuotes: true),
              ]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ShellPageHeader(
                        title: 'Markets',
                        subtitle: market.marketProvider.isNotEmpty
                            ? 'Live via ${market.marketProvider}'
                            : 'NSE · Premium market intelligence',
                        trailing: const LivePriceBadge(),
                      ),
                      if (market.isUsingDemoData) ...[
                        const SizedBox(height: 10),
                        const PremiumAlertBanner(
                          message:
                              'Showing demo NSE prices. Start Django on port 8000 for live Kotak Neo / Finnhub quotes.',
                          type: PremiumAlertType.info,
                        ),
                      ] else if (market.marketError != null) ...[
                        const SizedBox(height: 10),
                        PremiumAlertBanner(
                          message: market.marketError!,
                          type: PremiumAlertType.warning,
                          actionLabel: stocks.isEmpty ? 'Retry' : null,
                          onAction: stocks.isEmpty ? () => market.refresh() : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      const KycCompletionBanner(),
                    ]),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: MarketsStickySearchDelegate(
                    controller: _searchController,
                    onChanged: market.setSearchQuery,
                    onVoiceTap: _openVoiceSearch,
                  ),
                ),
                if (searching) ...[
                  if (market.isLoading && stocks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(color: AppColors.brandCyan)),
                    )
                  else if (stocks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No results for "${market.searchQuery}"',
                            style: ThemeAType.body(color: context.palette.textGrey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => StockListTile(stock: stocks[index]),
                        childCount: stocks.length,
                      ),
                    ),
                ] else ...[
                  SliverToBoxAdapter(child: MarketsPremiumOverview(indices: market.marketIndices)),
                  SliverToBoxAdapter(child: MarketsFnoIndicesSection(liveIndices: market.marketIndices)),
                  SliverToBoxAdapter(
                    child: MarketsQuickActions(
                      onMore: () => _showMoreSheet(context),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: MarketsHeatMapSectionAnchor.globalKey,
                      child: MarketsHeatMapSection(
                        onViewAll: () => context.push(AppRoutes.stockScreener),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: MarketsEconomicCalendarStrip(
                      onOpenFull: _openEconomicCalendar,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: MarketsPortfolioSummary(
                      portfolio: home.portfolio,
                      isLoading: home.isLoading,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: PaperRiskMeterCard.market(
                      meter: portfolio.marketRiskMeter,
                      isLoading: portfolio.riskLoading,
                    ),
                  ),
                  const SliverToBoxAdapter(child: MarketsWatchlistPreview()),
                  SliverToBoxAdapter(child: MarketsTopMovers(stocks: market.allStocks)),
                  SliverToBoxAdapter(child: MarketsNewsSection(news: home.marketNews)),
                  const SliverToBoxAdapter(child: MarketsTodayEvents()),
                  const SliverToBoxAdapter(child: MarketsLearningHub()),
                ],
                SliverPadding(padding: EdgeInsets.only(bottom: ShellLayout.contentBottomInset)),
              ],
            ),
          ),
        );
      },
    );
  }
}
