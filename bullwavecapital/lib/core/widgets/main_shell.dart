import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../features/stocks/presentation/provider/stock_portfolio_provider.dart';
import '../constants/routes.dart';
import '../constants/shell_layout.dart';
import '../theme/theme_a.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/bottom_navigation.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.portfolio)) return 1;
    if (location.startsWith(AppRoutes.invest)) return 2;
    if (location.startsWith(AppRoutes.wallet) ||
        location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.settings)) {
      return 3;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.read<StockPortfolioProvider>().ensureLoaded(refreshQuotes: false);
        context.go(AppRoutes.portfolio);
      case 2:
        context.go(AppRoutes.invest);
      case 3:
        _showMoreSheet(context);
    }
  }

  void _showCenterTradeSheet(BuildContext context) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.textGrey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Quick Trade', style: ThemeAType.sectionTitle(size: 17, color: p.textDark)),
              const SizedBox(height: 12),
              _ShellMenuTile(
                icon: PhosphorIcons.chartLineUp,
                label: 'Buy / Sell Stocks',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.invest);
                },
              ),
              _ShellMenuTile(
                icon: PhosphorIcons.trendUp,
                label: 'F&O Trading',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.optionChain);
                },
              ),
              _ShellMenuTile(
                icon: PhosphorIcons.flask,
                label: 'Paper Trading',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.paperTrading);
                },
              ),
              _ShellMenuTile(
                icon: Icons.bolt_rounded,
                label: 'Scalping',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.scalping);
                },
              ),
              _ShellMenuTile(
                icon: PhosphorIcons.repeat,
                label: 'SIP Investments',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.sipTracker);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.textGrey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('More', style: ThemeAType.sectionTitle(size: 17, color: p.textDark)),
              const SizedBox(height: 12),
              _ShellMenuTile(
                icon: PhosphorIcons.wallet,
                label: 'Wallet',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.wallet);
                },
              ),
              _ShellMenuTile(
                icon: PhosphorIcons.flag,
                label: 'Goal Plans',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.goalPlans);
                },
              ),
              _ShellMenuTile(
                icon: PhosphorIcons.bookmarkSimple,
                label: 'Watchlist',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.watchlist);
                },
              ),
              _ShellMenuTile(
                icon: PhosphorIcons.user,
                label: 'Profile',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.profile);
                },
              ),
              _ShellMenuTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.settings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          const AiAssistantFab(
            bottom: ShellLayout.fabBottomOffset,
            right: ShellLayout.fabRightOffset,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex(context),
        onTap: (index) => _onTap(context, index),
        onCenterTap: () => _showCenterTradeSheet(context),
      ),
    );
  }
}

class _ShellMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShellMenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: p.iconCircleDecoration(),
        child: Icon(icon, size: 18, color: p.primary),
      ),
      title: Text(label, style: ThemeAType.cardTitle(size: 14, color: p.textDark)),
      trailing: Icon(Icons.chevron_right_rounded, color: p.textMuted),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
