import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import '../../../fno/presentation/provider/fno_flow_provider.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../provider/option_trading_provider.dart';
import '../widgets/option_trading_pad.dart';

class OptionChainContext {
  final String assetClass;
  final String currencySymbol;
  final bool requiresFno;

  const OptionChainContext({
    required this.assetClass,
    this.currencySymbol = '₹',
    this.requiresFno = false,
  });

  static const commodity = OptionChainContext(
    assetClass: 'commodity',
    currencySymbol: '\$',
    requiresFno: false,
  );

  static const equityFno = OptionChainContext(
    assetClass: 'equity_fno',
    currencySymbol: '₹',
    requiresFno: true,
  );
}

Future<void> openOptionContractTradingPad(
  BuildContext context, {
  required OptionContractModel contract,
  required OptionChainContext chainContext,
  String initialSide = 'BUY',
}) async {
  if (!await ensureBankVerified(context)) return;
  if (!context.mounted) return;

  if (chainContext.requiresFno) {
    final fno = context.read<FnoFlowProvider>();
    await fno.ensureLoaded();
    if (!context.mounted) return;
    if (!fno.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete F&O verification to trade options.')),
      );
      return;
    }
  }

  final trading = context.read<OptionTradingProvider>();
  unawaited(trading.loadHoldings(assetClass: chainContext.assetClass));
  unawaited(context.read<WalletProvider>().loadData());

  await OptionTradingPad.show(
    context,
    contract: contract,
    chainContext: chainContext,
    initialSide: initialSide,
  );
}

String optionContractTitle(OptionContractModel contract, {String? underlyingName}) {
  final name = underlyingName ?? contract.symbol;
  final strike = contract.strike == contract.strike.roundToDouble()
      ? contract.strike.toStringAsFixed(0)
      : contract.strike.toStringAsFixed(2);
  return '$name $strike ${contract.type}';
}

String optionExpiryLabel(DateTime expiry) => DateFormatter.expiryLabel(
      expiry.toIso8601String().substring(0, 10),
    );

int optionLotSize(String underlying, String assetClass) {
  if (assetClass == 'commodity') return 1;
  switch (underlying.toUpperCase()) {
    case 'NIFTY':
    case 'FINNIFTY':
      return 25;
    case 'BANKNIFTY':
      return 15;
    default:
      return 1;
  }
}
