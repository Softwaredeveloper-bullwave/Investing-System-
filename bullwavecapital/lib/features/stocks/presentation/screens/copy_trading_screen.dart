import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/copy_trading_model.dart';
import '../provider/copy_trading_provider.dart';

class CopyTradingScreen extends StatefulWidget {
  const CopyTradingScreen({super.key});

  @override
  State<CopyTradingScreen> createState() => _CopyTradingScreenState();
}

class _CopyTradingScreenState extends State<CopyTradingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CopyTradingProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Copy Trading'),
      body: Consumer<CopyTradingProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: GlassCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copy verified trader methods',
                        style: ThemeAType.cardTitle(color: p.textDark, size: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse strategies, review their trade feed, then allocate capital to mirror their method.',
                        style: ThemeAType.body(color: p.textGrey, size: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabs,
                labelColor: p.primary,
                unselectedLabelColor: p.textMuted,
                indicatorColor: p.primary,
                tabs: const [
                  Tab(text: 'Discover'),
                  Tab(text: 'My Copies'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _DiscoverTab(
                      provider: provider,
                      searchController: _searchController,
                    ),
                    _MyCopiesTab(provider: provider),
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

class _DiscoverTab extends StatelessWidget {
  final CopyTradingProvider provider;
  final TextEditingController searchController;

  const _DiscoverTab({
    required this.provider,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (provider.isLoading && provider.traders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextField(
            controller: searchController,
            onSubmitted: (v) => provider.loadTraders(q: v.trim()),
            style: ThemeAType.body(color: p.textDark, size: 14),
            decoration: InputDecoration(
              hintText: 'Search traders or strategies',
              hintStyle: ThemeAType.body(color: p.textMuted, size: 14),
              prefixIcon: Icon(Icons.search_rounded, color: p.textMuted),
              filled: true,
              fillColor: p.surface.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RiskChip(
                  label: 'All',
                  selected: provider.riskFilter.isEmpty,
                  onTap: () => provider.loadTraders(risk: ''),
                ),
                _RiskChip(
                  label: 'Low',
                  selected: provider.riskFilter == 'low',
                  onTap: () => provider.loadTraders(risk: 'low'),
                ),
                _RiskChip(
                  label: 'Medium',
                  selected: provider.riskFilter == 'medium',
                  onTap: () => provider.loadTraders(risk: 'medium'),
                ),
                _RiskChip(
                  label: 'High',
                  selected: provider.riskFilter == 'high',
                  onTap: () => provider.loadTraders(risk: 'high'),
                ),
              ],
            ),
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(provider.error!, style: ThemeAType.body(color: p.negative, size: 13)),
          ],
          const SizedBox(height: 16),
          ...provider.traders.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TraderCard(
                trader: t,
                onTap: () => context.push('${AppRoutes.copyTraderDetail}?id=${t.id}'),
              ),
            ),
          ),
          if (!provider.isLoading && provider.traders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No verified traders found.',
                  style: ThemeAType.body(color: p.textMuted, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyCopiesTab extends StatelessWidget {
  final CopyTradingProvider provider;

  const _MyCopiesTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subs = provider.subscriptions;

    if (subs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_alt_outlined, size: 48, color: p.textMuted),
              const SizedBox(height: 12),
              Text(
                'You are not copying anyone yet',
                style: ThemeAType.cardTitle(color: p.textDark, size: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Open Discover, pick a verified trader, and allocate capital to follow their method.',
                style: ThemeAType.body(color: p.textGrey, size: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: provider.loadSubscriptions,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: subs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final sub = subs[index];
          return _SubscriptionCard(
            subscription: sub,
            onOpen: () =>
                context.push('${AppRoutes.copyTraderDetail}?id=${sub.trader.id}'),
            onPause: () => provider.setSubscriptionStatus(
              sub.id,
              sub.isPaused ? 'active' : 'paused',
            ),
            onStop: () => provider.setSubscriptionStatus(sub.id, 'stopped'),
          );
        },
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RiskChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ScaleTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: 0.16) : p.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? p.primary.withValues(alpha: 0.5) : p.borderLight,
            ),
          ),
          child: Text(
            label,
            style: ThemeAType.label(
              size: 12,
              color: selected ? p.primary : p.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TraderCard extends StatelessWidget {
  final CopyTraderModel trader;
  final VoidCallback onTap;

  const _TraderCard({required this.trader, required this.onTap});

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = _parseColor(trader.avatarColor);
    final ret = trader.return3m;

    return ScaleTap(
      onTap: onTap,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(
                    trader.initials,
                    style: ThemeAType.label(size: 14, color: accent)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trader.displayName,
                              style: ThemeAType.cardTitle(color: p.textDark, size: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trader.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded, size: 16, color: p.primary),
                          ],
                        ],
                      ),
                      Text(
                        '@${trader.handle} · ${trader.riskLabel}',
                        style: ThemeAType.label(size: 11, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}%',
                      style: ThemeAType.price(
                        color: ret >= 0 ? p.positive : p.negative,
                        size: 16,
                      ),
                    ),
                    Text('3M return', style: ThemeAType.label(size: 10, color: p.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              trader.strategyTitle,
              style: ThemeAType.body(color: p.textDark, size: 14)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              trader.bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThemeAType.body(color: p.textGrey, size: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: trader.methodTags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.borderLight),
                      ),
                      child: Text(tag, style: ThemeAType.label(size: 10, color: p.textMuted)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniStat(label: 'Win', value: '${trader.winRate.toStringAsFixed(0)}%'),
                const SizedBox(width: 12),
                _MiniStat(label: 'Copiers', value: '${trader.followersCount}'),
                const SizedBox(width: 12),
                _MiniStat(label: 'AUM', value: CurrencyFormatter.formatCompact(trader.aumInr)),
                const Spacer(),
                if (trader.isCopying)
                  Text('Copying', style: ThemeAType.label(size: 12, color: p.primary))
                else
                  Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ThemeAType.label(size: 9, color: p.textMuted)),
        Text(value, style: ThemeAType.label(size: 12, color: p.textDark)),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final CopySubscriptionModel subscription;
  final VoidCallback onOpen;
  final Future<String?> Function() onPause;
  final Future<String?> Function() onStop;

  const _SubscriptionCard({
    required this.subscription,
    required this.onOpen,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = subscription.trader;
    final pnl = subscription.copiedPnl;

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTap(
            onTap: onOpen,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.displayName, style: ThemeAType.cardTitle(color: p.textDark, size: 15)),
                      Text(
                        '${t.strategyTitle} · ${subscription.status.toUpperCase()}',
                        style: ThemeAType.label(size: 11, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                label: 'Allocation',
                value: CurrencyFormatter.format(subscription.allocationInr),
              ),
              const SizedBox(width: 16),
              _MiniStat(
                label: 'Copied PnL',
                value: CurrencyFormatter.format(pnl),
              ),
              const Spacer(),
              Text(
                subscription.autoCopy ? 'Auto-copy on' : 'Manual',
                style: ThemeAType.label(size: 11, color: p.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final err = await onPause();
                    if (!context.mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  child: Text(subscription.isPaused ? 'Resume' : 'Pause'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final err = await onStop();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err ?? 'Stopped copying ${t.displayName}'),
                        backgroundColor: err == null ? null : p.negative,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: p.negative),
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CopyTraderDetailScreen extends StatefulWidget {
  final String traderId;

  const CopyTraderDetailScreen({super.key, required this.traderId});

  @override
  State<CopyTraderDetailScreen> createState() => _CopyTraderDetailScreenState();
}

class _CopyTraderDetailScreenState extends State<CopyTraderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CopyTradingProvider>().loadTraderDetail(widget.traderId);
    });
  }

  Future<void> _openCopySheet(CopyTraderModel trader) async {
    final p = context.palette;
    final amountController = TextEditingController(
      text: trader.minCopyAmount.toStringAsFixed(0),
    );
    var autoCopy = true;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: p.borderLight),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy ${trader.displayName}',
                      style: ThemeAType.sectionTitle(color: p.textDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Allocate capital to mirror this verified method. Min ${CurrencyFormatter.format(trader.minCopyAmount)}.',
                      style: ThemeAType.body(color: p.textGrey, size: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Allocation (₹)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Auto-copy new trades', style: ThemeAType.body(color: p.textDark, size: 14)),
                      value: autoCopy,
                      activeThumbColor: p.primary,
                      onChanged: (v) => setModal(() => autoCopy = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Start copying'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final err = await context.read<CopyTradingProvider>().startCopy(
          traderId: trader.id,
          allocationInr: amount,
          autoCopy: autoCopy,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Now copying ${trader.displayName}’s method'),
        backgroundColor: err == null ? null : p.negative,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Trader method'),
      body: Consumer<CopyTradingProvider>(
        builder: (context, provider, _) {
          final trader = provider.selected;
          if (provider.isDetailLoading && trader == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (trader == null) {
            return Center(
              child: Text(
                provider.error ?? 'Trader not found',
                style: ThemeAType.body(color: p.textMuted, size: 14),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    GlassCard(
                      radius: 22,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Color(
                                  int.parse(
                                    'FF${trader.avatarColor.replaceFirst('#', '')}',
                                    radix: 16,
                                  ),
                                ).withValues(alpha: 0.22),
                                child: Text(
                                  trader.initials,
                                  style: ThemeAType.label(size: 16, color: p.primary)
                                      .copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            trader.displayName,
                                            style: ThemeAType.cardTitle(color: p.textDark, size: 18),
                                          ),
                                        ),
                                        if (trader.isVerified)
                                          Icon(Icons.verified_rounded, size: 18, color: p.primary),
                                      ],
                                    ),
                                    Text(
                                      '@${trader.handle} · ${trader.experienceYears} yrs',
                                      style: ThemeAType.label(size: 12, color: p.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(trader.strategyTitle, style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
                          const SizedBox(height: 6),
                          Text(trader.strategySummary, style: ThemeAType.body(color: p.textGrey, size: 13)),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ...trader.methodTags.map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(tag, style: ThemeAType.label(size: 11, color: p.primary)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: p.borderLight),
                                ),
                                child: Text(trader.riskLabel, style: ThemeAType.label(size: 11, color: p.textMuted)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _StatTile(label: '1M', value: _pct(trader.return1m), p: p)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatTile(label: '3M', value: _pct(trader.return3m), p: p)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatTile(label: '1Y', value: _pct(trader.return1y), p: p)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Win rate',
                            value: '${trader.winRate.toStringAsFixed(0)}%',
                            p: p,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'Max DD',
                            value: '${trader.maxDrawdown.toStringAsFixed(1)}%',
                            p: p,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'Copiers',
                            value: '${trader.followersCount}',
                            p: p,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Recent method trades', style: ThemeAType.sectionTitle(color: p.textDark, size: 16)),
                    const SizedBox(height: 10),
                    ...trader.recentTrades.map((trade) => _TradeTile(trade: trade)),
                    if (trader.recentTrades.isEmpty)
                      Text(
                        'No published trades yet.',
                        style: ThemeAType.body(color: p.textMuted, size: 13),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => trader.isCopying
                              ? context.push(AppRoutes.copyTrading)
                              : _openCopySheet(trader),
                      child: Text(
                        trader.isCopying ? 'Manage my copy' : 'Copy this method',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette p;

  const _StatTile({required this.label, required this.value, required this.p});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Text(label, style: ThemeAType.label(size: 10, color: p.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: ThemeAType.label(size: 13, color: p.textDark)),
        ],
      ),
    );
  }
}

class _TradeTile extends StatelessWidget {
  final CopyTraderTradeModel trade;

  const _TradeTile({required this.trade});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sideColor = trade.isBuy ? p.positive : p.negative;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sideColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trade.side,
                style: ThemeAType.label(size: 11, color: sideColor).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trade.symbol, style: ThemeAType.cardTitle(color: p.textDark, size: 14)),
                  Text(
                    '${trade.quantity} @ ${CurrencyFormatter.formatDecimal(trade.price)}'
                    '${trade.note.isNotEmpty ? ' · ${trade.note}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ThemeAType.body(color: p.textGrey, size: 12),
                  ),
                ],
              ),
            ),
            if (trade.pnlPercent != null)
              Text(
                '${trade.pnlPercent! >= 0 ? '+' : ''}${trade.pnlPercent!.toStringAsFixed(1)}%',
                style: ThemeAType.label(
                  size: 12,
                  color: trade.pnlPercent! >= 0 ? p.positive : p.negative,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
