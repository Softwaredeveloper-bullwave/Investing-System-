import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/stocks/presentation/provider/stock_portfolio_provider.dart';
import '../constants/routes.dart';
import '../constants/shell_layout.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/bottom_navigation.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.invest)) return 1;
    if (location.startsWith(AppRoutes.portfolio)) return 2;
    if (location.startsWith(AppRoutes.wallet)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.invest);
      case 2:
        context.read<StockPortfolioProvider>().ensureLoaded(refreshQuotes: false);
        context.go(AppRoutes.portfolio);
      case 3:
        context.go(AppRoutes.wallet);
      case 4:
        context.go(AppRoutes.profile);
    }
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
      ),
    );
  }
}
