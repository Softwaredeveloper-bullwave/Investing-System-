import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';

enum _BalanceCardStyle { hero, accent }

class HomeBalanceCards extends StatelessWidget {
  final double portfolioValue;
  final double walletBalance;
  final double dayPnl;
  final VoidCallback? onPortfolioTap;
  final VoidCallback? onWalletTap;

  const HomeBalanceCards({
    super.key,
    required this.portfolioValue,
    required this.walletBalance,
    this.dayPnl = 0,
    this.onPortfolioTap,
    this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BalanceCard(
            style: _BalanceCardStyle.hero,
            icon: PhosphorIcons.chartPie,
            amount: portfolioValue,
            label: 'Portfolio',
            sublabel: dayPnl != 0
                ? '${dayPnl >= 0 ? '+' : ''}${CurrencyFormatter.formatCompact(dayPnl)} today'
                : 'Total holdings',
            onTap: onPortfolioTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BalanceCard(
            style: _BalanceCardStyle.accent,
            icon: PhosphorIcons.wallet,
            amount: walletBalance,
            label: 'Wallet',
            sublabel: walletBalance > 0 ? 'Available balance' : 'Add funds',
            onTap: onWalletTap,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final _BalanceCardStyle style;
  final IconData icon;
  final double amount;
  final String label;
  final String sublabel;
  final VoidCallback? onTap;

  const _BalanceCard({
    required this.style,
    required this.icon,
    required this.amount,
    required this.label,
    required this.sublabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isHero = style == _BalanceCardStyle.hero;

    final fg = isHero ? p.heroCardFg : p.accentSurfaceFg;
    final muted = isHero ? p.heroCardMuted : p.accentSurfaceFg.withValues(alpha: 0.65);
    final decoration = isHero ? p.heroCardDecoration() : p.accentCardDecoration();
    final iconBg = isHero
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final iconFg = isHero ? p.heroCardFg : p.accentSurfaceFg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: iconFg),
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.formatCompact(amount),
                    style: ThemeAType.price(size: 24, color: fg),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: ThemeAType.cardTitle(size: 13, color: fg),
                ),
                const SizedBox(height: 3),
                Text(
                  sublabel,
                  style: ThemeAType.secondary(size: 12, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
