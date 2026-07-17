import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../models/commodity_model.dart';
import '../provider/commodity_provider.dart';
import '../widgets/commodity_trading_pad.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';

Future<void> openCommodityTradingPad(
  BuildContext context, {
  required CommodityModel commodity,
  String initialSide = 'BUY',
}) async {
  if (!await ensureBankVerified(context)) return;
  if (!context.mounted) return;

  final provider = context.read<CommodityProvider>();
  unawaited(provider.loadDetail(commodity.id));
  unawaited(provider.loadHoldings());
  unawaited(context.read<WalletProvider>().loadData());

  await CommodityTradingPad.show(
    context,
    commodity: commodity,
    initialSide: initialSide,
  );
}
