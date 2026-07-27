import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/stock_model.dart';
import '../provider/paper_competition_provider.dart';
import '../provider/paper_trading_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import '../utils/stock_trading_flow.dart';
import '../widgets/paper_competition_widgets.dart';
import '../widgets/simulation_badge.dart';
import '../widgets/stock_order_history_tile.dart';

class PaperTradingScreen extends StatefulWidget {
  const PaperTradingScreen({super.key});

  @override
  State<PaperTradingScreen> createState() => _PaperTradingScreenState();
}

class _PaperTradingScreenState extends State<PaperTradingScreen> {
  final _symbolController = TextEditingController(text: 'RELIANCE');
  bool _isLoading = true;
  bool _chartLoading = false;
  String? _chartSymbol;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _loadChart() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    if (symbol.isEmpty || symbol == _chartSymbol) return;
    _chartSymbol = symbol;
    setState(() => _chartLoading = true);
    await context.read<StockMarketProvider>().loadCandles(symbol, interval: '1d');
    if (mounted) setState(() => _chartLoading = false);
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final market = context.read<StockMarketProvider>();
    final features = context.read<StockFeaturesProvider>();
    final paperExtras = context.read<PaperCompetitionProvider>();
    setState(() => _isLoading = true);
    await market.ensureLoaded();
    await Future.wait([
      features.refreshPaperTrades(),
      features.loadPaperWallet(),
      paperExtras.refresh(),
    ]);
    if (mounted) setState(() => _isLoading = false);
    unawaited(_loadChart());
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset paper portfolio?'),
        content: const Text(
          'This clears every simulated position and order, and restores your '
          'starting virtual capital. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final features = context.read<StockFeaturesProvider>();
    final ok = await features.resetPaperPortfolio();
    if (!mounted) return;
    if (ok) {
      await context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paper portfolio reset. Fresh virtual capital is ready.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(features.tradeError ?? 'Could not reset. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmExitAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit all positions?'),
        content: const Text('Market-sells every open paper holding at the current price.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit All', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final paperTrading = context.read<PaperTradingProvider>();
    final ok = await paperTrading.exitAllPositions();
    if (!mounted) return;
    await Future.wait([
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false),
      context.read<StockFeaturesProvider>().refreshPaperTrades(),
      context.read<StockFeaturesProvider>().loadPaperWallet(),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'All positions exited.' : (paperTrading.error ?? 'Could not exit all positions.')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _place(String side) async {
    final symbol = _symbolController.text.trim().toUpperCase();
    final stock = context.read<StockMarketProvider>().getStock(symbol);
    if (stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unknown symbol. Pick a stock from Markets first.')),
      );
      return;
    }

    if (!mounted) return;
    await executeStockTrade(
      context,
      stock: stock,
      side: side,
    );
    if (!mounted) return;
    await Future.wait([
      context.read<StockFeaturesProvider>().refreshPaperTrades(),
      context.read<PaperCompetitionProvider>().refresh(),
    ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Paper Trading',
        actions: [
          IconButton(
            tooltip: 'Reset paper portfolio',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _isLoading ? null : _confirmReset,
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 4, itemHeight: 72),
            )
          : RefreshIndicator(
              color: AppColors.brandOrange,
              onRefresh: _load,
              child: Consumer3<StockFeaturesProvider, StockMarketProvider, PaperCompetitionProvider>(
                builder: (context, features, market, paperExtras, _) {
                  final symbol = _symbolController.text.trim().toUpperCase();
                  final stock = market.getStock(symbol);
                  final trades = features.paperTrades;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge()),
                      const SizedBox(height: 12),
                      _InfoBanner(colors: colors),
                      const SizedBox(height: 14),
                      _VirtualBalanceCard(
                        colors: colors,
                        balance: features.virtualBalance,
                        startingBalance: features.virtualStartingBalance,
                      ),
                      const SizedBox(height: 14),
                      _DashboardQuickLinks(onExitAll: _confirmExitAll),
                      const SizedBox(height: 14),
                      PaperRiskMeterCard(
                        meter: paperExtras.riskMeter,
                        isLoading: paperExtras.isLoading,
                      ),
                      const SizedBox(height: 14),
                      PaperCompetitionCard(
                        competitions: paperExtras.competitions,
                        isLoading: paperExtras.isSaving,
                        onCreate: () => showCreateCompetitionSheet(context),
                        onJoin: () => showJoinCompetitionSheet(context),
                        onOpen: (c) => showCompetitionDetailSheet(context, c),
                      ),
                      const SizedBox(height: 16),
                      _TradeForm(
                        colors: colors,
                        symbolController: _symbolController,
                        stock: stock,
                        isPlacing: false,
                        onSymbolChanged: () {
                          setState(() {});
                          unawaited(_loadChart());
                        },
                        onBuy: () => _place('BUY'),
                        onSell: () => _place('SELL'),
                        suggestions: market.trendingStocks.take(6).map((s) => s.symbol).toList(),
                        candles: market.getCandles(symbol, interval: '1d'),
                        chartLoading: _chartLoading,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Order History',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      if (trades.isEmpty)
                        _EmptyHistory(colors: colors)
                      else
                        ...trades.map((t) => StockOrderHistoryTile(order: t)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final AppThemeExtension colors;

  const _InfoBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: AppColors.brandOrange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Practice F&O trades with virtual money — no real funds at risk.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _VirtualBalanceCard extends StatelessWidget {
  final AppThemeExtension colors;
  final double? balance;
  final double? startingBalance;

  const _VirtualBalanceCard({
    required this.colors,
    required this.balance,
    required this.startingBalance,
  });

  @override
  Widget build(BuildContext context) {
    final bal = balance ?? 0;
    final start = startingBalance ?? 0;
    final deployed = start > 0 ? (start - bal).clamp(0, start) : 0;
    final usedPercent = start > 0 ? (deployed / start * 100).clamp(0, 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Virtual buying power',
                style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'of ${CurrencyFormatter.format(start)}',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(bal),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: start > 0 ? (bal / start).clamp(0, 1).toDouble() : 0,
              minHeight: 6,
              backgroundColor: colors.surfaceSecondary,
              valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${usedPercent.toStringAsFixed(0)}% deployed into positions',
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DashboardQuickLinks extends StatelessWidget {
  final VoidCallback onExitAll;

  const _DashboardQuickLinks({required this.onExitAll});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.bolt_rounded, 'Scalping', AppColors.red, AppRoutes.scalping),
      (Icons.pie_chart_rounded, 'Portfolio', AppColors.green, AppRoutes.paperPortfolio),
      (Icons.receipt_long_rounded, 'Order Book', AppColors.blue, AppRoutes.paperOrderBook),
      (Icons.candlestick_chart_rounded, 'Options', AppColors.brandPurple, '${AppRoutes.paperOptionChain}?symbol=NIFTY'),
      (Icons.local_fire_department_rounded, 'Commodities', AppColors.commodityGold, AppRoutes.paperCommodities),
      (Icons.menu_book_rounded, 'Journal', AppColors.brandPurple, AppRoutes.paperJournal),
      (Icons.insights_rounded, 'Analytics', AppColors.green, AppRoutes.paperAnalytics),
      (Icons.shield_outlined, 'Risk Limits', AppColors.brandOrange, AppRoutes.paperRiskLimits),
    ];

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: tiles.map((t) {
            final (icon, label, color, route) = t;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(route),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: AppDecorations.card(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: AppDecorations.iconBadge(color),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onExitAll,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Exit All Positions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TradeForm extends StatelessWidget {
  final AppThemeExtension colors;
  final TextEditingController symbolController;
  final StockModel? stock;
  final bool isPlacing;
  final VoidCallback onSymbolChanged;
  final VoidCallback onBuy;
  final VoidCallback onSell;
  final List<String> suggestions;
  final List<CandleModel> candles;
  final bool chartLoading;

  const _TradeForm({
    required this.colors,
    required this.symbolController,
    required this.stock,
    required this.isPlacing,
    required this.onSymbolChanged,
    required this.onBuy,
    required this.onSell,
    required this.suggestions,
    this.candles = const [],
    this.chartLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Place Order', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: symbolController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Symbol',
              hintText: 'e.g. RELIANCE',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => onSymbolChanged(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                onPressed: () {
                  symbolController.text = s;
                  onSymbolChanged();
                },
              );
            }).toList(),
          ),
          if (stock != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: TradingViewChart(
                key: ValueKey(stock!.symbol),
                symbol: stock!.symbol,
                intervalLabel: '1D',
                fallbackCandles: candles,
                isLoading: chartLoading,
                height: 160,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('LTP ', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                Text(
                  IndexFormatter.format(stock!.ltp),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  IndexFormatter.formatPercent(stock!.changePercent),
                  style: TextStyle(
                    color: stock!.isPositive ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Buy or Sell opens the order pad, where you set quantity and confirm at the live price.',
            style: TextStyle(color: colors.textMuted, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: isPlacing ? null : onBuy,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isPlacing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Buy', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isPlacing ? null : onSell,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(color: AppColors.red.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sell', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final AppThemeExtension colors;

  const _EmptyHistory({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No paper trades yet',
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Place a buy or sell order above to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
