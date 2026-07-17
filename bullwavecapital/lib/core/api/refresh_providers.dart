import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/home/presentation/provider/home_provider.dart';
import '../../features/notifications/presentation/provider/notification_provider.dart';
import '../../features/portfolio/presentation/provider/portfolio_provider.dart';
import '../../features/profile/presentation/provider/referral_support_provider.dart';
import '../../features/stocks/presentation/provider/stock_features_provider.dart';
import '../../features/stocks/presentation/provider/stock_market_provider.dart';
import '../../features/stocks/presentation/provider/stock_portfolio_provider.dart';
import '../../features/transactions/presentation/provider/transaction_provider.dart';
import '../../features/wallet/presentation/provider/wallet_provider.dart';

/// Reload authenticated data after login. Never blocks login — failures are ignored.
Future<void> refreshAllProviders(BuildContext context) async {
  final tasks = <Future<void>>[
    _safe(() => context.read<HomeProvider>().refresh()),
    _safe(() => context.read<WalletProvider>().loadData()),
    _safe(() => context.read<TransactionProvider>().loadData()),
    _safe(() => context.read<NotificationProvider>().loadData()),
    _safe(() => context.read<SupportProvider>().loadData()),
    _safe(() => context.read<ReferralProvider>().loadData()),
    _safe(() => context.read<PortfolioProvider>().loadData()),
    _safe(() => context.read<StockMarketProvider>().ensureLoaded()),
    _safe(() => context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false)),
    _safe(() => context.read<StockFeaturesProvider>().loadAll()),
  ];

  try {
    await Future.wait(tasks).timeout(const Duration(seconds: 20));
  } catch (_) {}
}

Future<void> _safe(Future<void> Function() task) async {
  try {
    await task().timeout(const Duration(seconds: 12));
  } catch (_) {}
}
