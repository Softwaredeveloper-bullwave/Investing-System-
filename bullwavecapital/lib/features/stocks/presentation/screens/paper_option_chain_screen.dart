import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/constants/fno_underlyings.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../utils/option_trading_flow.dart';
import '../widgets/option_chain_table.dart';
import '../widgets/paper_option_trading_pad.dart';
import '../widgets/simulation_badge.dart';

/// Paper-trading twin of [OptionChainScreen] — same live option chain data
/// (reuses `StockFeaturesProvider.loadOptionChain`, the same market-data
/// feed and `OptionChainTable` widget as real F&O trading) but every tap
/// opens [PaperOptionTradingPad] instead of the real trading pad, so orders
/// are simulated only. No F&O KYC gate — simulation doesn't need it.
class PaperOptionChainScreen extends StatefulWidget {
  final String symbol;

  const PaperOptionChainScreen({super.key, required this.symbol});

  @override
  State<PaperOptionChainScreen> createState() => _PaperOptionChainScreenState();
}

class _PaperOptionChainScreenState extends State<PaperOptionChainScreen> {
  late String _symbol;
  bool _chartLoading = false;

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol.toUpperCase();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final market = context.read<StockMarketProvider>();
    final features = context.read<StockFeaturesProvider>();
    final isIndex = FnoUnderlyings.isIndex(_symbol);
    if (!isIndex) {
      await market.ensureStock(_symbol);
    }
    await features.loadOptionChain(_symbol);
    // Index candles (NIFTY, BANKNIFTY, SENSEX, ...) now resolve server-side
    // to the right index ticker, same as individual stocks — fetch for both.
    if (mounted) {
      setState(() => _chartLoading = true);
      await market.loadCandles(_symbol, interval: '1d');
      if (mounted) setState(() => _chartLoading = false);
    }
  }

  Future<void> _selectSymbol(String symbol) async {
    final next = symbol.toUpperCase();
    if (next == _symbol) return;
    setState(() => _symbol = next);
    await _load();
  }

  String _formatExpiry(String iso) => DateFormatter.expiryLabel(iso);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sym = _symbol;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Paper F&O Chain'),
      // NOTE: the whole screen is ONE scrollable (not a Column with a
      // nested Expanded/ListView for just the chain table). The picker +
      // chart above the chain already eat a lot of fixed vertical space;
      // if the table lived inside its own Expanded, on shorter screens
      // that Expanded could be squeezed down to near-zero height, silently
      // rendering only the header with no visible rows ("chain not
      // showing" even though data loaded fine). Making the whole page one
      // scrollable guarantees every row is always reachable by scrolling,
      // regardless of screen height.
      body: Consumer2<StockFeaturesProvider, StockMarketProvider>(
        builder: (context, features, market, _) {
          final loading = features.isOptionChainLoading(sym);
          final chain = features.optionChain(sym);
          final error = features.optionChainError(sym);
          final spotFromChain = features.optionUnderlying(sym);
          final stock = market.getStock(sym);
          final spot = spotFromChain > 0 ? spotFromChain : (stock?.ltp ?? 0);
          final expiries = features.optionExpiries(sym);
          final selectedExpiry = features.optionSelectedExpiry(sym);

          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                ),
                _UnderlyingPicker(selected: sym, onSelected: _selectSymbol),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: TradingViewChart(
                      key: ValueKey(sym),
                      symbol: sym,
                      intervalLabel: '1D',
                      fallbackCandles: market.getCandles(sym, interval: '1d'),
                      isLoading: _chartLoading,
                      height: 180,
                    ),
                  ),
                ),
                if (loading && chain.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LoadingList(itemCount: 5, itemHeight: 56),
                  )
                else if (chain.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.candlestick_chart_outlined, size: 48, color: colors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          error ?? 'No F&O data for $sym',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
                        ),
                      ],
                    ),
                  )
                else ...[
                  OptionChainSummary(symbol: sym, spot: spot, contracts: chain),
                  if (expiries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: expiries.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final expiry = expiries[i];
                          final selected = expiry == selectedExpiry;
                          return Material(
                            color: selected ? AppColors.brandOrange.withValues(alpha: 0.15) : colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: loading ? null : () => features.loadOptionChain(sym, expiry: expiry),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected ? AppColors.brandOrange : colors.border.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Text(
                                  _formatExpiry(expiry),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12,
                                    color: selected ? AppColors.brandOrange : colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: LinearProgressIndicator(minHeight: 2, color: AppColors.brandOrange, backgroundColor: Colors.transparent),
                    ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Tap CE or PE price to paper buy or sell',
                      style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OptionChainTable(
                    contracts: chain,
                    spot: spot,
                    shrinkWrap: true,
                    onContractTap: (contract) => PaperOptionTradingPad.show(
                      context,
                      contract: contract,
                      chainContext: OptionChainContext.equityFno,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UnderlyingPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _UnderlyingPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select underlying', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: FnoUnderlyings.indices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final indexMeta = FnoUnderlyings.indices[index];
                final isSelected = selected == indexMeta.symbol;
                return Material(
                  color: isSelected ? AppColors.brandPrimary.withValues(alpha: 0.15) : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onSelected(indexMeta.symbol),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.brandPrimary : colors.border.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        indexMeta.label,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isSelected ? AppColors.brandPrimary : colors.textSecondary),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: FnoUnderlyings.stocks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final stock = FnoUnderlyings.stocks[i];
                final isSelected = selected == stock;
                return Material(
                  color: isSelected ? AppColors.brandOrange.withValues(alpha: 0.12) : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () => onSelected(stock),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: isSelected ? AppColors.brandOrange : colors.border.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        stock,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: isSelected ? AppColors.brandOrange : colors.textMuted),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
