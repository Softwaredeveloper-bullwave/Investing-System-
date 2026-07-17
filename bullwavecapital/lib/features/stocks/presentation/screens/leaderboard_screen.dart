import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/copy_trading_model.dart';
import '../provider/copy_trading_provider.dart';

enum _LeaderboardSort { m1, m3, y1, followers }

extension on _LeaderboardSort {
  String get label {
    switch (this) {
      case _LeaderboardSort.m1:
        return '1M';
      case _LeaderboardSort.m3:
        return '3M';
      case _LeaderboardSort.y1:
        return '1Y';
      case _LeaderboardSort.followers:
        return 'Followers';
    }
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _LeaderboardSort _sort = _LeaderboardSort.m3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CopyTradingProvider>().loadTraders();
    });
  }

  List<CopyTraderModel> _ranked(List<CopyTraderModel> traders) {
    final sorted = [...traders];
    switch (_sort) {
      case _LeaderboardSort.m1:
        sorted.sort((a, b) => b.return1m.compareTo(a.return1m));
      case _LeaderboardSort.m3:
        sorted.sort((a, b) => b.return3m.compareTo(a.return3m));
      case _LeaderboardSort.y1:
        sorted.sort((a, b) => b.return1y.compareTo(a.return1y));
      case _LeaderboardSort.followers:
        sorted.sort((a, b) => b.followersCount.compareTo(a.followersCount));
    }
    return sorted;
  }

  double _valueFor(CopyTraderModel t) {
    switch (_sort) {
      case _LeaderboardSort.m1:
        return t.return1m;
      case _LeaderboardSort.m3:
        return t.return3m;
      case _LeaderboardSort.y1:
        return t.return1y;
      case _LeaderboardSort.followers:
        return t.followersCount.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Leaderboard',
        subtitle: 'Top verified traders, ranked',
      ),
      body: Consumer<CopyTradingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.traders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.traders.isEmpty) {
            return _ErrorState(
              message: provider.error!,
              onRetry: () => provider.loadTraders(),
            );
          }

          final ranked = _ranked(provider.traders);

          return RefreshIndicator(
            color: p.primary,
            onRefresh: () => provider.loadTraders(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _LeaderboardSort.values
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ScaleTap(
                              onTap: () => setState(() => _sort = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _sort == s
                                      ? p.primary.withValues(alpha: 0.16)
                                      : p.surface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _sort == s ? p.primary.withValues(alpha: 0.45) : p.borderLight,
                                  ),
                                ),
                                child: Text(
                                  s.label,
                                  style: ThemeAType.label(size: 12, color: _sort == s ? p.primary : p.textMuted)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ...ranked.asMap().entries.map(
                      (entry) => _LeaderboardTile(
                        rank: entry.key + 1,
                        trader: entry.value,
                        value: _valueFor(entry.value),
                        isPercent: _sort != _LeaderboardSort.followers,
                        onTap: () => context.push('${AppRoutes.copyTraderDetail}?id=${entry.value.id}'),
                      ),
                    ),
                if (ranked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No ranked traders yet.', style: ThemeAType.body(color: p.textMuted)),
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

Color _rankColor(int rank) {
  switch (rank) {
    case 1:
      return const Color(0xFFFFD700);
    case 2:
      return const Color(0xFFC0C0C0);
    case 3:
      return const Color(0xFFCD7F32);
    default:
      return Colors.transparent;
  }
}

Color _parseHexColor(String hex, {double alpha = 1}) {
  final clean = hex.replaceFirst('#', '');
  final base = Color(int.parse('FF$clean', radix: 16));
  return alpha == 1 ? base : base.withValues(alpha: alpha);
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final CopyTraderModel trader;
  final double value;
  final bool isPercent;
  final VoidCallback onTap;

  const _LeaderboardTile({
    required this.rank,
    required this.trader,
    required this.value,
    required this.isPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isTopThree = rank <= 3;
    final valueColor = !isPercent ? p.textDark : (value >= 0 ? p.positive : p.negative);
    final valueText = isPercent
        ? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%'
        : value.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ScaleTap(
        onTap: onTap,
        child: GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          glow: isTopThree,
          glowColor: isTopThree ? _rankColor(rank) : null,
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: isTopThree
                    ? Icon(Icons.emoji_events_rounded, color: _rankColor(rank), size: 24)
                    : Text(
                        '#$rank',
                        style: ThemeAType.label(size: 14, color: p.textMuted).copyWith(fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 22,
                backgroundColor: _parseHexColor(trader.avatarColor, alpha: 0.22),
                child: Text(
                  trader.initials,
                  style: ThemeAType.label(size: 14, color: _parseHexColor(trader.avatarColor)).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trader.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.cardTitle(color: p.textDark, size: 14),
                    ),
                    Text(
                      trader.strategyTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.body(color: p.textGrey, size: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: ThemeAType.label(size: 15, color: valueColor).copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${trader.followersCount} followers',
                    style: ThemeAType.label(size: 10, color: p.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: p.negative.withValues(alpha: 0.8)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ThemeAType.body(color: p.textGrey, size: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.primary,
                side: BorderSide(color: p.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
