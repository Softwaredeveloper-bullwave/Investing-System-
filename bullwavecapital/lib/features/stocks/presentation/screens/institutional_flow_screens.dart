import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/institutional_flow_model.dart';
import '../provider/institutional_flow_provider.dart';

class BlockDealTrackerScreen extends StatefulWidget {
  const BlockDealTrackerScreen({super.key});

  @override
  State<BlockDealTrackerScreen> createState() => _BlockDealTrackerScreenState();
}

class _BlockDealTrackerScreenState extends State<BlockDealTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstitutionalFlowProvider>().loadBlockDeals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Block Deal Tracker'),
      body: Consumer<InstitutionalFlowProvider>(
        builder: (context, provider, _) {
          if (provider.blockLoading && provider.blockDeals.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = provider.blockSummary;
          return RefreshIndicator(
            color: p.primary,
            onRefresh: () => provider.loadBlockDeals(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NSE / BSE block & bulk deals',
                        style: ThemeAType.cardTitle(color: p.textDark, size: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track large negotiated prints — who bought/sold, premium to LTP, and deal value.',
                        style: ThemeAType.body(color: p.textGrey, size: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryPill(
                              label: 'Buy ₹ Cr',
                              value: summary.buyValueCr.toStringAsFixed(1),
                              color: p.positive,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryPill(
                              label: 'Sell ₹ Cr',
                              value: summary.sellValueCr.toStringAsFixed(1),
                              color: p.negative,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryPill(
                              label: 'Net ₹ Cr',
                              value: summary.netValueCr.toStringAsFixed(1),
                              color: summary.netValueCr >= 0 ? p.positive : p.negative,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: provider.dealTypeFilter.isEmpty && provider.sideFilter.isEmpty,
                        onTap: () => provider.loadBlockDeals(dealType: '', side: ''),
                      ),
                      _FilterChip(
                        label: 'Block',
                        selected: provider.dealTypeFilter == 'block',
                        onTap: () => provider.loadBlockDeals(dealType: 'block'),
                      ),
                      _FilterChip(
                        label: 'Bulk',
                        selected: provider.dealTypeFilter == 'bulk',
                        onTap: () => provider.loadBlockDeals(dealType: 'bulk'),
                      ),
                      _FilterChip(
                        label: 'Buy',
                        selected: provider.sideFilter == 'BUY',
                        onTap: () => provider.loadBlockDeals(side: 'BUY'),
                      ),
                      _FilterChip(
                        label: 'Sell',
                        selected: provider.sideFilter == 'SELL',
                        onTap: () => provider.loadBlockDeals(side: 'SELL'),
                      ),
                    ],
                  ),
                ),
                if (provider.blockError != null) ...[
                  const SizedBox(height: 12),
                  _InlineErrorBanner(
                    message: provider.blockError!,
                    onRetry: () => provider.loadBlockDeals(),
                  ),
                ],
                const SizedBox(height: 14),
                ...provider.blockDeals.map((d) => _BlockDealTile(deal: d)),
                if (!provider.blockLoading && provider.blockDeals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No block deals found.', style: ThemeAType.body(color: p.textMuted)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DarkPoolTrackerScreen extends StatefulWidget {
  const DarkPoolTrackerScreen({super.key});

  @override
  State<DarkPoolTrackerScreen> createState() => _DarkPoolTrackerScreenState();
}

class _DarkPoolTrackerScreenState extends State<DarkPoolTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstitutionalFlowProvider>().loadDarkPool();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Dark Pool Tracker'),
      body: Consumer<InstitutionalFlowProvider>(
        builder: (context, provider, _) {
          if (provider.darkLoading && provider.darkPrints.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = provider.darkSummary;
          return RefreshIndicator(
            color: p.primary,
            onRefresh: () => provider.loadDarkPool(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Off-exchange institutional prints',
                        style: ThemeAType.cardTitle(color: p.textDark, size: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitor dark / negotiated venue flow vs VWAP to spot quiet accumulation or distribution.',
                        style: ThemeAType.body(color: p.textGrey, size: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryPill(
                              label: 'Value ₹ Cr',
                              value: summary.totalValueCr.toStringAsFixed(1),
                              color: p.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryPill(
                              label: 'Buy bias',
                              value: '${summary.buyBiased}',
                              color: p.positive,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryPill(
                              label: 'vs VWAP',
                              value: '${summary.avgVsVwap >= 0 ? '+' : ''}${summary.avgVsVwap.toStringAsFixed(2)}%',
                              color: summary.avgVsVwap >= 0 ? p.positive : p.negative,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: provider.biasFilter.isEmpty,
                        onTap: () => provider.loadDarkPool(bias: ''),
                      ),
                      _FilterChip(
                        label: 'Buy-biased',
                        selected: provider.biasFilter == 'buy',
                        onTap: () => provider.loadDarkPool(bias: 'buy'),
                      ),
                      _FilterChip(
                        label: 'Sell-biased',
                        selected: provider.biasFilter == 'sell',
                        onTap: () => provider.loadDarkPool(bias: 'sell'),
                      ),
                      _FilterChip(
                        label: 'Mixed',
                        selected: provider.biasFilter == 'mixed',
                        onTap: () => provider.loadDarkPool(bias: 'mixed'),
                      ),
                    ],
                  ),
                ),
                if (provider.darkError != null) ...[
                  const SizedBox(height: 12),
                  _InlineErrorBanner(
                    message: provider.darkError!,
                    onRetry: () => provider.loadDarkPool(),
                  ),
                ],
                const SizedBox(height: 14),
                ...provider.darkPrints.map((print_) => _DarkPoolTile(print_: print_)),
                if (!provider.darkLoading && provider.darkPrints.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No dark pool prints found.', style: ThemeAType.body(color: p.textMuted)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.negative.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.negative.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: p.negative, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: ThemeAType.body(color: p.textDark, size: 13).copyWith(height: 1.4),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    'Retry',
                    style: ThemeAType.label(size: 12, color: p.negative).copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
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

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: ThemeAType.label(size: 13, color: color).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ScaleTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: 0.16) : p.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? p.primary.withValues(alpha: 0.45) : p.borderLight),
          ),
          child: Text(
            label,
            style: ThemeAType.label(size: 12, color: selected ? p.primary : p.textMuted),
          ),
        ),
      ),
    );
  }
}

class _BlockDealTile extends StatelessWidget {
  final BlockDealModel deal;

  const _BlockDealTile({required this.deal});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sideColor = deal.isBuy ? p.positive : p.negative;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ScaleTap(
        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${deal.symbol}'),
        child: GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      deal.side,
                      style: ThemeAType.label(size: 11, color: sideColor).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.borderLight),
                    ),
                    child: Text(
                      deal.isBlock ? 'BLOCK' : 'BULK',
                      style: ThemeAType.label(size: 10, color: p.textMuted),
                    ),
                  ),
                  const Spacer(),
                  Text(deal.exchange, style: ThemeAType.label(size: 11, color: p.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              Text(deal.symbol, style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
              Text(deal.companyName, style: ThemeAType.body(color: p.textGrey, size: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(label: 'Price', value: CurrencyFormatter.formatDecimal(deal.price)),
                  _Stat(label: 'Qty', value: _compactQty(deal.quantity)),
                  _Stat(label: 'Value', value: '₹${deal.valueCr.toStringAsFixed(1)} Cr'),
                  _Stat(
                    label: 'vs LTP',
                    value: '${deal.premiumPercent >= 0 ? '+' : ''}${deal.premiumPercent.toStringAsFixed(2)}%',
                    color: deal.premiumPercent >= 0 ? p.positive : p.negative,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${deal.clientName.isEmpty ? 'Institutional' : deal.clientName} · ${deal.counterparty}',
                style: ThemeAType.label(size: 11, color: p.textMuted),
              ),
              Text(
                DateFormatter.displayWithTime(deal.tradedAt),
                style: ThemeAType.label(size: 10, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _compactQty(int qty) {
  if (qty >= 10000000) return '${(qty / 10000000).toStringAsFixed(2)} Cr';
  if (qty >= 100000) return '${(qty / 100000).toStringAsFixed(2)} L';
  if (qty >= 1000) return '${(qty / 1000).toStringAsFixed(1)}K';
  return qty.toString();
}

class _DarkPoolTile extends StatelessWidget {
  final DarkPoolPrintModel print_;

  const _DarkPoolTile({required this.print_});

  Color _biasColor(ThemePalette p) {
    switch (print_.bias) {
      case 'buy':
        return p.positive;
      case 'sell':
        return p.negative;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final biasColor = _biasColor(p);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ScaleTap(
        onTap: () => context.push('${AppRoutes.stockDetail}?symbol=${print_.symbol}'),
        child: GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: biasColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      print_.bias.toUpperCase(),
                      style: ThemeAType.label(size: 10, color: biasColor).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      print_.venue,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.label(size: 11, color: p.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(print_.symbol, style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
              Text(print_.companyName, style: ThemeAType.body(color: p.textGrey, size: 12)),
              if (print_.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(print_.note, style: ThemeAType.body(color: p.textDark, size: 12)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(label: 'Price', value: CurrencyFormatter.formatDecimal(print_.price)),
                  _Stat(label: 'Qty', value: _compactQty(print_.quantity)),
                  _Stat(label: 'Value', value: '₹${print_.valueCr.toStringAsFixed(1)} Cr'),
                  _Stat(
                    label: 'vs VWAP',
                    value: '${print_.vsVwapPercent >= 0 ? '+' : ''}${print_.vsVwapPercent.toStringAsFixed(2)}%',
                    color: print_.vsVwapPercent >= 0 ? p.positive : p.negative,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DateFormatter.displayWithTime(print_.printTime),
                style: ThemeAType.label(size: 10, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ThemeAType.label(size: 9, color: p.textMuted)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ThemeAType.label(size: 11, color: color ?? p.textDark),
          ),
        ],
      ),
    );
  }
}
