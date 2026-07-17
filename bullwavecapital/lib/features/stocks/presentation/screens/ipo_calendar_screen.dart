import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_features_provider.dart';

class IpoCalendarScreen extends StatefulWidget {
  const IpoCalendarScreen({super.key});

  @override
  State<IpoCalendarScreen> createState() => _IpoCalendarScreenState();
}

class _IpoCalendarScreenState extends State<IpoCalendarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _isLoading = true;

  static const _filters = [
    ('all', 'All'),
    ('open', 'Open'),
    ('upcoming', 'Upcoming'),
    ('closed', 'Closed'),
    ('listed', 'Listed'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<StockFeaturesProvider>().refreshIpoCalendar();
    if (mounted) setState(() => _isLoading = false);
  }

  List<IpoEventModel> _filtered(List<IpoEventModel> events, String key) {
    if (key == 'all') return events;
    return events.where((e) => e.status == key).toList();
  }

  Future<void> _showOrderSheet(IpoEventModel event, {required bool isSell}) async {
    if (!await ensureBankVerified(context)) return;
    if (!mounted) return;

    final features = context.read<StockFeaturesProvider>();
    final holding = features.ipoHoldingFor(event.id);
    final maxLots = isSell ? (holding?.lots ?? 0) : 10;
    if (isSell && maxLots < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no lots to sell for this IPO.')),
      );
      return;
    }

    var lots = 1;
    final price = isSell ? (event.listingPrice > 0 ? event.listingPrice : event.priceBandMax) : event.applyPrice;
    final colors = context.appColors;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final amount = lots * event.lotSize * price;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(ctx).bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSell ? 'Sell IPO' : 'Apply for IPO',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(event.companyName, style: TextStyle(color: colors.textSecondary)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lots', style: TextStyle(color: colors.textSecondary)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: lots > 1 ? () => setSheetState(() => lots--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$lots',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          IconButton(
                            onPressed: lots < maxLots ? () => setSheetState(() => lots++) : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SheetRow(
                    label: 'Lot size',
                    value: '${event.lotSize} shares',
                    colors: colors,
                  ),
                  _SheetRow(
                    label: 'Price',
                    value: '₹${price.toStringAsFixed(0)}/share',
                    colors: colors,
                  ),
                  _SheetRow(
                    label: 'Total',
                    value: CurrencyFormatter.format(amount),
                    colors: colors,
                    bold: true,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isSell ? AppColors.red : AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        isSell ? 'Confirm Sell' : 'Apply & Pay from Wallet',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final ok = await features.placeIpoOrder(
      ipoId: event.id,
      side: isSell ? 'SELL' : 'APPLY',
      lots: lots,
    );
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSell ? 'IPO sold successfully!' : 'IPO application submitted!'),
          backgroundColor: AppColors.green,
        ),
      );
      setState(() {});
    } else if (features.ipoTradeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(features.ipoTradeError!), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'IPO Calendar',
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: colors.primaryDark,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          indicator: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 4),
          tabs: _filters.map((f) => Tab(text: f.$2)).toList(),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingList(itemCount: 5, itemHeight: 120),
            )
          : RefreshIndicator(
              color: colors.primaryDark,
              backgroundColor: colors.surface,
              onRefresh: _load,
              child: Consumer<StockFeaturesProvider>(
                builder: (context, features, _) {
                  final events = features.ipoEvents;
                  final holdings = features.ipoHoldings;
                  final trades = features.ipoTrades;
                  final openCount = events.where((e) => e.isOpen).length;

                  return Column(
                    children: [
                      if (holdings.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _HoldingsPanel(holdings: holdings, colors: colors),
                        ),
                      if (events.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _SummaryStrip(openCount: openCount, colors: colors),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: _filters.map((filter) {
                            final rows = _filtered(events, filter.$1);
                            if (rows.isEmpty) {
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
                                  Center(
                                    child: Text(
                                      'No ${filter.$2.toLowerCase()} IPOs right now',
                                      style: TextStyle(color: colors.textSecondary),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: rows.length + (filter.$1 == 'all' && trades.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (filter.$1 == 'all' && trades.isNotEmpty && index == rows.length) {
                                  return _RecentTrades(trades: trades.take(5).toList(), colors: colors);
                                }
                                final event = rows[index];
                                final holding = features.ipoHoldingFor(event.id);
                                return _IpoCard(
                                  event: event,
                                  holding: holding,
                                  colors: colors,
                                  onApply: () => _showOrderSheet(event, isSell: false),
                                  onSell: () => _showOrderSheet(event, isSell: true),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;
  final bool bold;

  const _SheetRow({
    required this.label,
    required this.value,
    required this.colors,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingsPanel extends StatelessWidget {
  final List<IpoHoldingModel> holdings;
  final AppThemeExtension colors;

  const _HoldingsPanel({required this.holdings, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = holdings.fold(0.0, (sum, h) => sum + h.currentValueInr);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.heroCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My IPO Holdings', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(total),
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          ...holdings.map(
            (h) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      h.companyName,
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${h.lots} lot(s)',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${h.pnlPercent >= 0 ? '+' : ''}${h.pnlPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: h.pnlInr >= 0 ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int openCount;
  final AppThemeExtension colors;

  const _SummaryStrip({required this.openCount, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (openCount == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.green.withValues(alpha: 0.16),
            AppColors.green.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: AppColors.green, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$openCount IPO${openCount == 1 ? '' : 's'} open for subscription',
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTrades extends StatelessWidget {
  final List<IpoTradeModel> trades;
  final AppThemeExtension colors;

  const _RecentTrades({required this.trades, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Recent IPO Orders', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...trades.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  t.isApply ? Icons.shopping_cart_outlined : Icons.sell_outlined,
                  color: t.isApply ? AppColors.green : AppColors.red,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.companyName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                      Text(
                        '${t.isApply ? 'Applied' : 'Sold'} ${t.lots} lot(s)',
                        style: TextStyle(color: colors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(t.amountInr),
                  style: TextStyle(
                    color: t.isApply ? colors.textPrimary : AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IpoCard extends StatelessWidget {
  final IpoEventModel event;
  final IpoHoldingModel? holding;
  final AppThemeExtension colors;
  final VoidCallback onApply;
  final VoidCallback onSell;

  const _IpoCard({
    required this.event,
    required this.holding,
    required this.colors,
    required this.onApply,
    required this.onSell,
  });

  Color _statusColor() {
    switch (event.status) {
      case 'open':
        return AppColors.green;
      case 'upcoming':
        return AppColors.blue;
      case 'closed':
        return AppColors.yellow;
      case 'listed':
        return AppColors.brandPink;
      default:
        return colors.textSecondary;
    }
  }

  String _statusLabel() => event.status.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final canApply = event.isOpen;
    final canSell = event.isListed && (holding?.lots ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(statusColor.withValues(alpha: 0.08), colors.surface),
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.companyName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.sector} • ${event.exchange}',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _statusLabel(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: 'Price band', value: event.priceBandLabel, colors: colors),
              if (event.isListed && event.listingPrice > 0)
                _InfoPill(
                  label: 'Listing',
                  value: '₹${event.listingPrice.toStringAsFixed(0)}',
                  colors: colors,
                  highlight: AppColors.green,
                ),
              if (event.gmpPercent != null)
                _InfoPill(
                  label: 'GMP',
                  value: '+${event.gmpPercent!.toStringAsFixed(1)}%',
                  colors: colors,
                  highlight: AppColors.green,
                ),
              if (holding != null)
                _InfoPill(
                  label: 'Your lots',
                  value: '${holding!.lots}',
                  colors: colors,
                  highlight: AppColors.brandOrange,
                ),
            ],
          ),
          if (canApply || canSell) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (canApply)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onApply,
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (canApply && canSell) const SizedBox(width: 10),
                if (canSell)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onSell,
                      icon: const Icon(Icons.sell_rounded, size: 18),
                      label: const Text('Sell', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;
  final Color? highlight;

  const _InfoPill({
    required this.label,
    required this.value,
    required this.colors,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: highlight ?? colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
