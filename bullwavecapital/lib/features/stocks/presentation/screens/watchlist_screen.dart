import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/stock_market_provider.dart';
import '../widgets/stock_list_tile.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final market = context.read<StockMarketProvider>();
    await market.ensureLoaded();
    await market.refreshWatchlist();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Watchlist',
        actions: [
          Consumer<StockMarketProvider>(
            builder: (context, market, _) {
              return IconButton(
                icon: market.watchlistLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandOrange.withValues(alpha: 0.8),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                onPressed: market.watchlistLoading ? null : _load,
              );
            },
          ),
        ],
      ),
      body: Consumer<StockMarketProvider>(
        builder: (context, market, _) {
          if (market.watchlistLoading && market.watchlistStocks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingList(itemCount: 5, itemHeight: 72),
            );
          }

          final stocks = market.watchlistStocks;

          if (stocks.isEmpty) {
            return RefreshIndicator(
              color: AppColors.brandOrange,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: AppDecorations.card(context),
                    child: Column(
                      children: [
                        Icon(Icons.bookmarks_rounded, size: 56, color: AppColors.brandPrimary.withValues(alpha: 0.7)),
                        const SizedBox(height: 16),
                        Text(
                          'Your watchlist is empty',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          market.watchlistError ??
                              'Bookmark stocks from Markets or stock detail to track them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandOrange,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          ),
                          child: const Text('Browse Markets'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: stocks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      '${stocks.length} stocks • Live prices',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                final stock = stocks[index - 1];
                return Dismissible(
                  key: ValueKey(stock.symbol),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: AppColors.red.withValues(alpha: 0.12),
                    child: const Icon(Icons.bookmark_remove_rounded, color: AppColors.red),
                  ),
                  onDismissed: (_) async {
                    final err = await market.toggleWatchlist(stock.symbol);
                    if (context.mounted && err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                      );
                      await market.refreshWatchlist();
                    }
                  },
                  child: StockListTile(stock: stock),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.invest),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Stock'),
      ),
    );
  }
}
