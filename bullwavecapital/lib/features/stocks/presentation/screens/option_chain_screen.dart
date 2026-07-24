import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';



import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/constants/fno_underlyings.dart';
import '../../../fno/presentation/provider/fno_flow_provider.dart';

import '../../../../core/theme/app_theme_extension.dart';

import '../../../../core/theme/colors.dart';

import '../../../../core/utils/formatters.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';

import '../provider/stock_features_provider.dart';

import '../provider/stock_market_provider.dart';

import '../utils/option_trading_flow.dart';
import '../widgets/option_chain_table.dart';



class OptionChainScreen extends StatefulWidget {

  final String symbol;



  const OptionChainScreen({super.key, required this.symbol});



  @override

  State<OptionChainScreen> createState() => _OptionChainScreenState();

}



class _OptionChainScreenState extends State<OptionChainScreen> {

  late String _symbol;
  bool _chartLoading = false;



  @override

  void initState() {

    super.initState();

    _symbol = widget.symbol.toUpperCase();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());

  }



  Future<void> _load() async {
    final fno = context.read<FnoFlowProvider>();
    await fno.ensureLoaded();
    if (!mounted) return;
    if (!fno.isVerified) {
      context.replace(AppRoutes.fnoVerification);
      return;
    }

    final market = context.read<StockMarketProvider>();
    final features = context.read<StockFeaturesProvider>();

    if (!FnoUnderlyings.isIndex(_symbol)) {
      await market.ensureStock(_symbol);
    }

    await features.loadOptionChain(_symbol);

    // Underlying candles for the mini chart above the chain — same feed
    // used on the paper F&O chain and stock detail screens.
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

      appBar: const CustomAppBar(title: 'F&O Chain'),

      // Whole screen is ONE scrollable — see the identical fix on
      // PaperOptionChainScreen. Keeping the chain table inside its own
      // Expanded (below a picker + chart that both eat fixed vertical
      // space) risked squeezing it to near-zero height on shorter screens.
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
          final needsFno = error == '__fno_required__';

          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
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
                        Icon(
                          needsFno ? Icons.verified_user_outlined : Icons.candlestick_chart_outlined,
                          size: 48,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          needsFno
                              ? 'Complete F&O verification to access the option chain.'
                              : (error ?? 'No F&O data for $sym'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: needsFno
                              ? () => context.replace(AppRoutes.fnoVerification)
                              : _load,
                          icon: Icon(needsFno ? Icons.arrow_forward_rounded : Icons.refresh_rounded),
                          label: Text(needsFno ? 'Verify F&O Access' : 'Retry'),
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
                            color: selected
                                ? AppColors.brandOrange.withValues(alpha: 0.15)
                                : colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: loading
                                  ? null
                                  : () => features.loadOptionChain(sym, expiry: expiry),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.brandOrange
                                        : colors.border.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Text(
                                  _formatExpiry(expiry),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
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
                      'Tap CE or PE price to buy or sell',
                      style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OptionChainTable(
                    contracts: chain,
                    spot: spot,
                    shrinkWrap: true,
                    onContractTap: (contract) => openOptionContractTradingPad(
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

      decoration: BoxDecoration(

        border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5))),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            'Select underlying',

            style: TextStyle(

              fontSize: 11,

              fontWeight: FontWeight.w700,

              color: colors.textMuted,

              letterSpacing: 0.5,

            ),

          ),

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
                  color: isSelected
                      ? AppColors.brandPrimary.withValues(alpha: 0.15)
                      : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onSelected(indexMeta.symbol),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : colors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        indexMeta.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: isSelected ? AppColors.brandPrimary : colors.textSecondary,
                        ),
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

                  color: isSelected

                      ? AppColors.brandOrange.withValues(alpha: 0.12)

                      : colors.surfaceSecondary,

                  borderRadius: BorderRadius.circular(999),

                  child: InkWell(

                    onTap: () => onSelected(stock),

                    borderRadius: BorderRadius.circular(999),

                    child: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                      decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(999),

                        border: Border.all(

                          color: isSelected

                              ? AppColors.brandOrange

                              : colors.border.withValues(alpha: 0.5),

                        ),

                      ),

                      child: Text(

                        stock,

                        style: TextStyle(

                          fontWeight: FontWeight.w700,

                          fontSize: 11,

                          color: isSelected ? AppColors.brandOrange : colors.textMuted,

                        ),

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


