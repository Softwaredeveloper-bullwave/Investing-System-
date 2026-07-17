import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_portfolio_provider.dart';
import '../widgets/stock_trading_pad.dart';

/// Opens Dhan-style trading pad (Buy/Sell toggle, live price, order summary).
Future<void> openStockTradingPad(
  BuildContext context, {
  required StockModel stock,
  String initialSide = 'BUY',
}) async {
  if (!await ensureBankVerified(context)) return;
  if (!context.mounted) return;

  final portfolio = context.read<StockPortfolioProvider>();
  unawaited(portfolio.loadPortfolio(refreshQuotes: false));

  await StockTradingPad.show(
    context,
    stock: stock,
    initialSide: initialSide,
  );
}

/// Entry point for Buy / Sell from stock detail, portfolio, paper trading.
Future<void> executeStockTrade(
  BuildContext context, {
  required StockModel stock,
  required String side,
}) =>
    openStockTradingPad(context, stock: stock, initialSide: side);
