import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/option_trade_model.dart';

class OptionTradingProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<OptionHoldingModel> _holdings = [];
  bool _loadingHoldings = false;
  String? _tradeError;

  List<OptionHoldingModel> get holdings => List.unmodifiable(_holdings);
  bool get loadingHoldings => _loadingHoldings;
  String? get tradeError => _tradeError;

  Future<void> loadHoldings({String? assetClass}) async {
    _loadingHoldings = true;
    notifyListeners();
    try {
      _holdings = await _api.getOptionHoldings(assetClass: assetClass);
      _tradeError = null;
    } catch (_) {
      _holdings = [];
    }
    _loadingHoldings = false;
    notifyListeners();
  }

  int holdingLots({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String assetClass,
  }) {
    final expiryKey = expiry.toIso8601String().substring(0, 10);
    for (final h in _holdings) {
      if (h.underlying == underlying.toUpperCase() &&
          h.assetClass == assetClass &&
          h.optionType == optionType.toUpperCase() &&
          h.strike == strike &&
          h.expiry.toIso8601String().substring(0, 10) == expiryKey) {
        return h.quantity;
      }
    }
    return 0;
  }

  Future<OptionTradeModel?> placeOrder({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String side,
    required int quantity,
    required double premium,
    required String assetClass,
  }) async {
    _tradeError = null;
    notifyListeners();
    try {
      final trade = await _api.placeOptionOrder(
        underlying: underlying,
        strike: strike,
        optionType: optionType,
        expiry: expiry,
        side: side,
        quantity: quantity,
        premium: premium,
        assetClass: assetClass,
      );
      await loadHoldings(assetClass: assetClass);
      return trade;
    } on ApiException catch (e) {
      _tradeError = e.message;
    } catch (_) {
      _tradeError = 'Could not place option order.';
    }
    notifyListeners();
    return null;
  }
}
