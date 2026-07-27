import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/fno_index_catalog.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/stock_model.dart';
import '../../../fno/presentation/provider/fno_flow_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../utils/option_trading_flow.dart';
import '../widgets/option_chain_table.dart';
import '../widgets/stock_detail_chart.dart';

/// Index F&O hub — chart, market analysis, and full option chain (OI · LTP · Strike).
class IndexFnoHubScreen extends StatefulWidget {
  final String symbol;

  const IndexFnoHubScreen({super.key, required this.symbol});

  @override
  State<IndexFnoHubScreen> createState() => _IndexFnoHubScreenState();
}

class _IndexFnoHubScreenState extends State<IndexFnoHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late String _symbol;
  String _intervalLabel = '1D';
  bool _chartLoading = false;

  FnoIndexMeta get _meta =>
      FnoIndexCatalog.bySymbol(_symbol) ??
      const FnoIndexMeta(symbol: 'NIFTY', label: 'Nifty 50', exchange: 'NSE', marketIndexKey: 'NIFTY');

  String get _apiInterval {
    for (final item in stockChartIntervals) {
      if (item.label == _intervalLabel) return item.apiInterval;
    }
    return '1d';
  }

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol.toUpperCase();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final fno = context.read<FnoFlowProvider>();
    await fno.ensureLoaded();
    if (!mounted) return;
    if (!fno.isVerified) {
      context.replace(AppRoutes.fnoVerification);
      return;
    }
    await _loadChain();
    if (!mounted) return;
    await context.read<StockMarketProvider>().loadCandles(_symbol, interval: _apiInterval);
  }

  Future<void> _loadChain() async {
    await context.read<StockFeaturesProvider>().loadOptionChain(_symbol);
  }

  Future<void> _onIntervalChange(String label) async {
    if (label == _intervalLabel) return;
    setState(() {
      _intervalLabel = label;
      _chartLoading = true;
    });
    await context.read<StockMarketProvider>().loadCandles(_symbol, interval: _apiInterval);
    if (mounted) setState(() => _chartLoading = false);
  }

  double _spot(StockFeaturesProvider features, StockMarketProvider market) {
    final fromChain = features.optionUnderlying(_symbol);
    if (fromChain > 0) return fromChain;
    for (final idx in market.marketIndices) {
      if (idx.shortName.toUpperCase().contains(_meta.marketIndexKey)) return idx.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: _meta.label),
      body: Consumer2<StockFeaturesProvider, StockMarketProvider>(
        builder: (context, features, market, _) {
          final loading = features.isOptionChainLoading(_symbol);
          final chain = features.optionChain(_symbol);
          final error = features.optionChainError(_symbol);
          final spot = _spot(features, market);
          final expiries = features.optionExpiries(_symbol);
          final selectedExpiry = features.optionSelectedExpiry(_symbol);
          final candles = market.getCandles(_symbol, interval: _apiInterval);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IndexHeader(meta: _meta, spot: spot, loading: loading && chain.isEmpty),
              Material(
                color: p.card.withValues(alpha: 0.5),
                child: TabBar(
                  controller: _tabs,
                  labelColor: p.primary,
                  unselectedLabelColor: p.textMuted,
                  indicatorColor: p.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Chart'),
                    Tab(text: 'Analysis'),
                    Tab(text: 'Option Chain'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _ChartTab(
                      symbol: _symbol,
                      exchange: _meta.exchange,
                      candles: candles,
                      isLoading: _chartLoading,
                      intervalLabel: _intervalLabel,
                      onIntervalChange: _onIntervalChange,
                      spot: spot,
                    ),
                    _AnalysisTab(
                      symbol: _symbol,
                      spot: spot,
                      contracts: chain,
                    ),
                    _OptionChainTab(
                      symbol: _symbol,
                      spot: spot,
                      chain: chain,
                      loading: loading,
                      error: error,
                      expiries: expiries,
                      selectedExpiry: selectedExpiry,
                      onExpiry: (e) => features.loadOptionChain(_symbol, expiry: e),
                      onRefresh: _loadChain,
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IndexHeader extends StatelessWidget {
  final FnoIndexMeta meta;
  final double spot;
  final bool loading;

  const _IndexHeader({required this.meta, required this.spot, required this.loading});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.label, style: ThemeAType.sectionTitle(color: p.textDark, size: 20)),
                Text('${meta.exchange} · Index F&O', style: ThemeAType.body(color: p.textGrey, size: 12)),
              ],
            ),
          ),
          if (loading)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  spot > 0 ? IndexFormatter.format(spot) : '—',
                  style: ThemeAType.sectionTitle(color: p.textDark, size: 22),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.positive.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('LIVE', style: ThemeAType.label(size: 10, color: p.positive)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChartTab extends StatelessWidget {
  final String symbol;
  final String exchange;
  final List<CandleModel> candles;
  final bool isLoading;
  final String intervalLabel;
  final ValueChanged<String> onIntervalChange;
  final double spot;

  const _ChartTab({
    required this.symbol,
    required this.exchange,
    required this.candles,
    required this.isLoading,
    required this.intervalLabel,
    required this.onIntervalChange,
    required this.spot,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (candles.isEmpty && !isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            spot > 0
                ? 'Index spot ${IndexFormatter.format(spot)} — candle history loading…'
                : 'Chart data unavailable for $symbol',
            textAlign: TextAlign.center,
            style: ThemeAType.body(color: p.textGrey),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: StockDetailChart(
        symbol: symbol,
        exchange: exchange,
        candles: candles,
        isLoading: isLoading,
        selectedLabel: intervalLabel,
        onIntervalSelected: onIntervalChange,
      ),
    );
  }
}

class _AnalysisTab extends StatelessWidget {
  final String symbol;
  final double spot;
  final List<OptionContractModel> contracts;

  const _AnalysisTab({
    required this.symbol,
    required this.spot,
    required this.contracts,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final calls = contracts.where((c) => c.type == 'CE');
    final puts = contracts.where((c) => c.type == 'PE');
    final callOi = calls.fold<int>(0, (s, c) => s + c.oi);
    final putOi = puts.fold<int>(0, (s, c) => s + c.oi);
    final pcr = callOi > 0 ? putOi / callOi : 0.0;
    final bias = pcr > 1.1 ? 'Bearish skew' : pcr < 0.9 ? 'Bullish skew' : 'Neutral';

    final support = spot > 0 ? spot * 0.985 : 0.0;
    final resistance = spot > 0 ? spot * 1.015 : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _AnalysisCard(
          title: 'Market flash',
          child: Text(
            '$symbol ${spot > 0 ? "trading at ${IndexFormatter.format(spot)}" : "option chain active"}. '
            'PCR ${pcr.toStringAsFixed(2)} suggests $bias. Watch max-OI strikes for intraday pivots.',
            style: ThemeAType.body(color: p.textDark, size: 14).copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricTile(label: 'PCR', value: pcr.toStringAsFixed(2), color: p.primary)),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(label: 'Call OI', value: _fmtOi(callOi), color: p.positive)),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(label: 'Put OI', value: _fmtOi(putOi), color: p.negative)),
          ],
        ),
        const SizedBox(height: 12),
        _AnalysisCard(
          title: 'Key levels',
          child: Column(
            children: [
              _LevelRow(label: 'Support', value: support > 0 ? IndexFormatter.format(support) : '—', color: p.positive),
              const SizedBox(height: 8),
              _LevelRow(label: 'Resistance', value: resistance > 0 ? IndexFormatter.format(resistance) : '—', color: p.negative),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AnalysisCard(
          title: 'F&O snapshot',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Weekly expiry contracts loaded from live spot', style: ThemeAType.body(color: p.textGrey, size: 13)),
              const SizedBox(height: 6),
              Text('• Tap CE/PE LTP in Option Chain to place paper orders', style: ThemeAType.body(color: p.textGrey, size: 13)),
              const SizedBox(height: 6),
              Text('• OI bars highlight concentration at each strike', style: ThemeAType.body(color: p.textGrey, size: 13)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtOi(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _AnalysisCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _AnalysisCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: p.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ThemeAType.cardTitle(color: p.textDark, size: 15)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: ThemeAType.cardTitle(color: color, size: 16)),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LevelRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: ThemeAType.body(color: p.textGrey, size: 13)),
        const Spacer(),
        Text(value, style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
      ],
    );
  }
}

class _OptionChainTab extends StatelessWidget {
  final String symbol;
  final double spot;
  final List<OptionContractModel> chain;
  final bool loading;
  final String? error;
  final List<String> expiries;
  final String selectedExpiry;
  final ValueChanged<String> onExpiry;
  final Future<void> Function() onRefresh;
  final AppThemeExtension colors;

  const _OptionChainTab({
    required this.symbol,
    required this.spot,
    required this.chain,
    required this.loading,
    required this.error,
    required this.expiries,
    required this.selectedExpiry,
    required this.onExpiry,
    required this.onRefresh,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && chain.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: LoadingList(itemCount: 6, itemHeight: 52));
    }
    if (chain.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error ?? 'No option chain for $symbol', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptionChainSummary(symbol: symbol, spot: spot, contracts: chain),
        if (expiries.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: expiries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final expiry = expiries[i];
                final selected = expiry == selectedExpiry;
                return FilterChip(
                  selected: selected,
                  label: Text(DateFormatter.expiryLabel(expiry), style: const TextStyle(fontSize: 11)),
                  onSelected: loading ? null : (_) => onExpiry(expiry),
                  selectedColor: AppColors.brandPrimary.withValues(alpha: 0.15),
                );
              },
            ),
          ),
        ],
        if (loading)
          const LinearProgressIndicator(minHeight: 2, color: AppColors.brandPrimary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Calls ←  OI · LTP  |  STRIKE  |  LTP · OI  → Puts',
            style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: OptionChainTable(
              contracts: chain,
              spot: spot,
              onContractTap: (contract) => openOptionContractTradingPad(
                context,
                contract: contract,
                chainContext: OptionChainContext.equityFno,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
