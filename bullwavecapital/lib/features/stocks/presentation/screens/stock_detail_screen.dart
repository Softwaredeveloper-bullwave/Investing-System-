import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../provider/stock_market_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import '../utils/stock_trading_flow.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../models/stock_model.dart';
import '../widgets/stock_detail_chart.dart';
import '../widgets/stock_list_tile.dart';
import '../widgets/technical_indicators_panel.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  bool _isLoading = true;
  bool _chartLoading = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _loadCandles({bool showChartLoader = false}) async {
    if (showChartLoader && mounted) setState(() => _chartLoading = true);
    await context.read<StockMarketProvider>().loadCandles(
          widget.symbol,
          interval: _apiInterval,
        );
    if (mounted) setState(() => _chartLoading = false);
  }

  Future<void> _load() async {
    final market = context.read<StockMarketProvider>();
    await Future.wait([
      market.ensureStock(widget.symbol),
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false),
    ]);
    if (mounted) setState(() => _isLoading = false);
    await _loadCandles();
  }

  Future<void> _onIntervalChange(String label) async {
    if (label == _intervalLabel) return;
    setState(() => _intervalLabel = label);
    await _loadCandles(showChartLoader: true);
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<StockMarketProvider>().ensureStock(widget.symbol),
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: true),
    ]);
    await _loadCandles(showChartLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<StockMarketProvider>(
      builder: (context, market, _) {
        if (_isLoading) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: CustomAppBar(title: widget.symbol),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 4, itemHeight: 80),
            ),
          );
        }

        final stock = market.getStock(widget.symbol);
        if (stock == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: const CustomAppBar(title: 'Stock'),
            body: const Center(child: Text('Stock not found')),
          );
        }

        final candles = market.getCandles(widget.symbol, interval: _apiInterval);
        final indicators = market.getIndicators(widget.symbol, interval: _apiInterval);
        final isPositive = stock.isPositive;
        final changeColor = isPositive ? AppColors.green : AppColors.red;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            title: stock.symbol,
            actions: [
              IconButton(
                icon: Icon(
                  market.isInWatchlist(stock.symbol)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: market.isInWatchlist(stock.symbol)
                      ? AppColors.brandPink
                      : colors.textMuted,
                ),
                onPressed: () async {
                  final err = await market.toggleWatchlist(stock.symbol);
                  if (context.mounted && err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.brandOrange,
                    onRefresh: _onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        _PriceHero(
                          stock: stock,
                          isPositive: isPositive,
                          changeColor: changeColor,
                        ),
                        Consumer<StockPortfolioProvider>(
                          builder: (context, portfolio, _) {
                            StockHoldingModel? holding;
                            for (final h in portfolio.holdings) {
                              if (h.symbol == stock.symbol) {
                                holding = h;
                                break;
                              }
                            }
                            if (holding == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: _PositionCard(holding: holding),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: StockDetailChart(
                            symbol: widget.symbol,
                            candles: candles,
                            isLoading: _chartLoading,
                            selectedLabel: _intervalLabel,
                            onIntervalSelected: _onIntervalChange,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TechnicalIndicatorsPanel(indicators: indicators),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Market Stats',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _StatsGrid(stock: stock),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ActionTile(
                                  icon: Icons.candlestick_chart_outlined,
                                  label: 'Options',
                                  color: AppColors.blue,
                                  onTap: () => context.push(
                                    '${AppRoutes.optionChain}?symbol=${widget.symbol}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ActionTile(
                                  icon: Icons.science_outlined,
                                  label: 'Paper Trade',
                                  color: AppColors.brandPurple,
                                  onTap: () => context.push(AppRoutes.paperTrading),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _TradeBar(stock: stock),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PriceHero extends StatelessWidget {
  final StockModel stock;
  final bool isPositive;
  final Color changeColor;

  const _PriceHero({
    required this.stock,
    required this.isPositive,
    required this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: AppDecorations.heroCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  stock.exchange,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (stock.sector.isNotEmpty)
                Flexible(
                  child: Text(
                    stock.sector,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stock.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MoneyText(
                  amount: IndexFormatter.format(stock.ltp),
                  fontSize: 36,
                ),
              ),
              const LivePriceBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 16,
                  color: changeColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${IndexFormatter.formatChange(stock.change)} (${IndexFormatter.formatPercent(stock.changePercent)})',
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final StockModel stock;

  const _StatsGrid({required this.stock});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Open', IndexFormatter.format(stock.open), Icons.lock_open_rounded),
      _StatItem('High', IndexFormatter.format(stock.high), Icons.north_east_rounded, AppColors.green),
      _StatItem('Low', IndexFormatter.format(stock.low), Icons.south_east_rounded, AppColors.red),
      _StatItem('Prev Close', IndexFormatter.format(stock.previousClose), Icons.history_rounded),
      _StatItem('Volume', '${(stock.volume / 100000).toStringAsFixed(2)}L', Icons.bar_chart_rounded),
      _StatItem('P/E', stock.pe.toStringAsFixed(1), Icons.analytics_outlined),
      _StatItem('52W High', IndexFormatter.format(stock.week52High), Icons.arrow_upward_rounded, AppColors.green),
      _StatItem('52W Low', IndexFormatter.format(stock.week52Low), Icons.arrow_downward_rounded, AppColors.red),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _StatCard(item: items[i]),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  const _StatItem(this.label, this.value, this.icon, [this.accent]);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = item.accent ?? AppColors.brandOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: AppDecorations.iconBadge(accent),
            child: Icon(item.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
                ),
                Text(
                  item.value,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: AppDecorations.card(context),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: AppDecorations.iconBadge(color),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final StockHoldingModel holding;

  const _PositionCard({required this.holding});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pnlColor = holding.isPositive ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                'Your Position',
                style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _PosMetric(label: 'Qty', value: '${holding.quantity}')),
              Expanded(child: _PosMetric(label: 'Avg', value: CurrencyFormatter.format(holding.avgPrice))),
              Expanded(child: _PosMetric(label: 'Invested', value: CurrencyFormatter.formatCompact(holding.invested))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Value', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                  Text(
                    CurrencyFormatter.format(holding.currentValue),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total P&L', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                  Text(
                    '${holding.pnl >= 0 ? '+' : ''}${CurrencyFormatter.format(holding.pnl)}',
                    style: TextStyle(color: pnlColor, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  Text(
                    '${holding.pnlPercent >= 0 ? '+' : ''}${holding.pnlPercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: pnlColor, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PosMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PosMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

class _TradeBar extends StatelessWidget {
  final StockModel stock;

  const _TradeBar({required this.stock});

  Future<void> _openPad(BuildContext context, String side) async {
    await openStockTradingPad(context, stock: stock, initialSide: side);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final holdingQty = context.watch<StockPortfolioProvider>().holdingQtyFor(stock.symbol);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => _openPad(context, 'BUY'),
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
                onPressed: () => _openPad(context, 'SELL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: BorderSide(
                    color: AppColors.red.withValues(alpha: holdingQty > 0 ? 0.7 : 0.4),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  holdingQty > 0 ? 'Sell' : 'Sell',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
