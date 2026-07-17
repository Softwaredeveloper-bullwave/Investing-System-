import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_screen_background.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/commodity_provider.dart';
import '../utils/option_trading_flow.dart';
import '../widgets/option_chain_table.dart';

class CommodityOptionChainScreen extends StatefulWidget {
  final String commodityId;

  const CommodityOptionChainScreen({super.key, required this.commodityId});

  @override
  State<CommodityOptionChainScreen> createState() => _CommodityOptionChainScreenState();
}

class _CommodityOptionChainScreenState extends State<CommodityOptionChainScreen> {
  late String _commodityId;

  static const _commodityList = [
    ('GOLD', 'Gold', AppColors.commodityGold),
    ('SILVER', 'Silver', AppColors.commoditySilver),
    ('CRUDE_OIL', 'Crude', AppColors.commodityEnergy),
    ('NATURAL_GAS', 'Gas', AppColors.commodityEnergy),
    ('COPPER', 'Copper', AppColors.commodityMetal),
  ];

  @override
  void initState() {
    super.initState();
    _commodityId = widget.commodityId.toUpperCase();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<CommodityProvider>().loadOptionChain(_commodityId);
  }

  int _strikeDecimals(double spot) {
    if (spot < 10) return 2;
    if (spot < 100) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      body: AppScreenBackground(
        child: Column(
          children: [
            PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Consumer<CommodityProvider>(
                builder: (context, p, _) {
                  final name = p.commodityById(_commodityId)?.shortName ?? 'Options';
                  return CustomAppBar(
                    title: '$name Options',
                    subtitle: 'MCX-style chain • USD',
                  );
                },
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _commodityList.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (id, label, accent) = _commodityList[i];
                  final selected = id == _commodityId;
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    showCheckmark: false,
                    avatar: selected
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                          )
                        : null,
                    selectedColor: accent.withValues(alpha: 0.18),
                    backgroundColor: colors.surfaceSecondary,
                    side: BorderSide(
                      color: selected ? accent.withValues(alpha: 0.5) : colors.border,
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? accent : colors.textSecondary,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      if (id == _commodityId) return;
                      setState(() => _commodityId = id);
                      _load();
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: Consumer<CommodityProvider>(
                builder: (context, provider, _) {
                  final loading = provider.isOptionChainLoading(_commodityId);
                  final chain = provider.optionChain(_commodityId);
                  final error = provider.optionChainError(_commodityId);
                  final spot = provider.optionUnderlying(_commodityId);
                  final commodity = provider.commodityById(_commodityId);
                  final unit = commodity?.unit ?? 'USD';

                  if (loading && chain.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: LoadingList(itemCount: 6, itemHeight: 56),
                    );
                  }

                  if (chain.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.candlestick_chart_outlined, size: 48, color: colors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              error ?? 'No options data',
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
                      ),
                    );
                  }

                  final expiries = provider.optionExpiries(_commodityId);
                  final selectedExpiry = provider.optionSelectedExpiry(_commodityId);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: AppDecorations.card(context, premium: true, glow: true),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Spot', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                    Text(
                                      '\$${IndexFormatter.format(spot)}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                                    ),
                                    Text(unit, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.green),
                                    SizedBox(width: 4),
                                    Text('LIVE', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (expiries.isNotEmpty) ...[
                        const SizedBox(height: 12),
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
                              return Material(
                                color: selected
                                    ? AppColors.brandOrange.withValues(alpha: 0.16)
                                    : colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: loading
                                      ? null
                                      : () => provider.loadOptionChain(_commodityId, expiry: expiry),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected ? AppColors.brandOrange : colors.border,
                                      ),
                                    ),
                                    child: Text(
                                      DateFormatter.expiryLabel(expiry),
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
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Tap CE or PE price to buy or sell',
                          style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: OptionChainTable(
                          contracts: chain,
                          spot: spot,
                          strikeDecimals: _strikeDecimals(spot),
                          currencySymbol: '\$',
                          onContractTap: (contract) => openOptionContractTradingPad(
                            context,
                            contract: contract,
                            chainContext: OptionChainContext.commodity,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
