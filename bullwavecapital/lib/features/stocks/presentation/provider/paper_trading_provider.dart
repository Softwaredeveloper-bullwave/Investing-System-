import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/commodity_model.dart';
import '../../../../models/option_trade_model.dart';
import '../../../../models/paper_portfolio_model.dart';
import '../../../../models/paper_trading_model.dart';

/// Dedicated state for the Paper Trading module — order book (market/limit/
/// SL-M/SL), ledger, journal, analytics, risk limits. Deliberately separate
/// from [StockFeaturesProvider]'s existing paper-trading fields (paperTrades,
/// virtualBalance, reset) so that provider's contract stays untouched; this
/// one is additive.
class PaperTradingProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<PaperOrderModel> _orderBook = [];
  List<PaperLedgerEntryModel> _ledger = [];
  List<PaperJournalEntryModel> _journal = [];
  PaperAnalyticsModel _analytics = PaperAnalyticsModel.empty;
  PaperRiskStatusModel _riskStatus = PaperRiskStatusModel.empty;

  bool _isLoadingOrderBook = false;
  bool _isPlacingOrder = false;
  bool _isLoadingAnalytics = false;
  bool _isLoadingLedger = false;
  bool _isLoadingJournal = false;
  bool _isExitingAll = false;
  String? _error;

  List<PaperOrderModel> get orderBook => _orderBook;
  List<PaperOrderModel> get pendingOrders =>
      _orderBook.where((o) => o.isPending).toList();
  List<PaperLedgerEntryModel> get ledger => _ledger;
  List<PaperJournalEntryModel> get journal => _journal;
  PaperAnalyticsModel get analytics => _analytics;
  PaperRiskStatusModel get riskStatus => _riskStatus;
  bool get isLoadingOrderBook => _isLoadingOrderBook;
  bool get isPlacingOrder => _isPlacingOrder;
  bool get isLoadingAnalytics => _isLoadingAnalytics;
  bool get isLoadingLedger => _isLoadingLedger;
  bool get isLoadingJournal => _isLoadingJournal;
  bool get isExitingAll => _isExitingAll;
  String? get error => _error;

  Future<void> loadOrderBook({String? status}) async {
    _isLoadingOrderBook = true;
    _error = null;
    notifyListeners();
    try {
      _orderBook = await _api.getPaperOrderBook(status: status);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the order book.';
    }
    _isLoadingOrderBook = false;
    notifyListeners();
  }

  Future<PaperOrderModel?> placeOrder({
    required String symbol,
    required String side,
    required int quantity,
    String orderType = 'MARKET',
    double? limitPrice,
    double? triggerPrice,
  }) async {
    _isPlacingOrder = true;
    _error = null;
    notifyListeners();
    try {
      final order = await _api.placePaperOrder(
        symbol: symbol,
        side: side,
        quantity: quantity,
        orderType: orderType,
        limitPrice: limitPrice,
        triggerPrice: triggerPrice,
      );
      _orderBook = [order, ..._orderBook.where((o) => o.id != order.id)];
      _isPlacingOrder = false;
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Order failed. Try again.';
    }
    _isPlacingOrder = false;
    notifyListeners();
    return null;
  }

  Future<bool> modifyOrder(
    String orderId, {
    int? quantity,
    double? limitPrice,
    double? triggerPrice,
  }) async {
    try {
      final updated = await _api.modifyPaperOrder(
        orderId, quantity: quantity, limitPrice: limitPrice, triggerPrice: triggerPrice,
      );
      _orderBook = _orderBook.map((o) => o.id == updated.id ? updated : o).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not modify order.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      final cancelled = await _api.cancelPaperOrder(orderId);
      _orderBook = _orderBook.map((o) => o.id == cancelled.id ? cancelled : o).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not cancel order.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> exitPosition(String symbol) async {
    try {
      await _api.exitPaperPosition(symbol);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not exit position.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> exitAllPositions() async {
    _isExitingAll = true;
    notifyListeners();
    try {
      await _api.exitAllPaperPositions();
      _isExitingAll = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not exit all positions.';
    }
    _isExitingAll = false;
    notifyListeners();
    return false;
  }

  Future<void> loadLedger() async {
    _isLoadingLedger = true;
    notifyListeners();
    try {
      _ledger = await _api.getPaperLedger();
    } catch (_) {}
    _isLoadingLedger = false;
    notifyListeners();
  }

  Future<void> loadJournal() async {
    _isLoadingJournal = true;
    notifyListeners();
    try {
      _journal = await _api.getPaperJournal();
    } catch (_) {}
    _isLoadingJournal = false;
    notifyListeners();
  }

  Future<bool> createJournalEntry({
    required String title,
    String notes = '',
    String symbol = '',
    String? tradeId,
    String lessonLearned = '',
    String mood = '',
    int? rating,
  }) async {
    try {
      final entry = await _api.createPaperJournalEntry(
        title: title, notes: notes, symbol: symbol, tradeId: tradeId,
        lessonLearned: lessonLearned, mood: mood, rating: rating,
      );
      _journal = [entry, ..._journal];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not save journal entry.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> deleteJournalEntry(String entryId) async {
    try {
      await _api.deletePaperJournalEntry(entryId);
      _journal = _journal.where((e) => e.id != entryId).toList();
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Could not delete journal entry.';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAnalytics() async {
    _isLoadingAnalytics = true;
    notifyListeners();
    try {
      _analytics = await _api.getPaperAnalytics();
    } catch (_) {}
    _isLoadingAnalytics = false;
    notifyListeners();
  }

  Future<void> loadRiskStatus() async {
    try {
      _riskStatus = await _api.getPaperRiskStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updateRiskLimit({
    double? maxDailyLoss,
    double? maxPositionSizePercent,
    bool? isActive,
  }) async {
    try {
      await _api.updatePaperRiskLimit(
        maxDailyLoss: maxDailyLoss,
        maxPositionSizePercent: maxPositionSizePercent,
        isActive: isActive,
      );
      await loadRiskStatus();
      return true;
    } catch (_) {
      _error = 'Could not update risk limit.';
      notifyListeners();
      return false;
    }
  }

  // ─── Paper Options (equity F&O + commodity options) ─────────────────────
  // Reuses OptionHoldingModel/OptionTradeModel — same shape as real options,
  // just sourced from /paper-trading/options/... and settled against the
  // paper wallet, never finance.Wallet.

  List<OptionTradeModel> _optionOrders = [];
  List<OptionHoldingModel> _optionHoldings = [];
  bool _isLoadingOptionOrders = false;
  bool _isPlacingOptionOrder = false;

  List<OptionTradeModel> get optionOrders => _optionOrders;
  List<OptionHoldingModel> get optionHoldings => _optionHoldings;
  bool get isLoadingOptionOrders => _isLoadingOptionOrders;
  bool get isPlacingOptionOrder => _isPlacingOptionOrder;

  Future<void> loadOptionOrders() async {
    _isLoadingOptionOrders = true;
    notifyListeners();
    try {
      _optionOrders = await _api.getPaperOptionOrders();
      _optionHoldings = await _api.getPaperOptionHoldings();
    } catch (_) {}
    _isLoadingOptionOrders = false;
    notifyListeners();
  }

  Future<OptionTradeModel?> placeOptionOrder({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String side,
    required int quantity,
    required double premium,
    String assetClass = 'equity_fno',
  }) async {
    _isPlacingOptionOrder = true;
    _error = null;
    notifyListeners();
    try {
      final order = await _api.placePaperOptionOrder(
        underlying: underlying, strike: strike, optionType: optionType,
        expiry: expiry, side: side, quantity: quantity, premium: premium,
        assetClass: assetClass,
      );
      _optionOrders = [order, ..._optionOrders];
      // Refresh holdings immediately so Sell unlocks right after a Buy
      // fills, without needing to close and reopen the trading pad.
      try {
        _optionHoldings = await _api.getPaperOptionHoldings();
      } catch (_) {}
      _isPlacingOptionOrder = false;
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Option order failed. Try again.';
    }
    _isPlacingOptionOrder = false;
    notifyListeners();
    return null;
  }

  Future<bool> exitOptionPosition(OptionHoldingModel holding, double premium) async {
    try {
      await _api.exitPaperOptionPosition(
        underlying: holding.underlying, strike: holding.strike,
        optionType: holding.optionType, expiry: holding.expiry,
        premium: premium, assetClass: holding.assetClass,
      );
      await loadOptionOrders();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not exit option position.';
    }
    notifyListeners();
    return false;
  }

  // ─── Paper Commodities ────────────────────────────────────────────────
  // Reuses CommodityHoldingModel/CommodityTradeModel.

  List<CommodityTradeModel> _commodityOrders = [];
  List<CommodityHoldingModel> _commodityHoldings = [];
  bool _isLoadingCommodityOrders = false;
  bool _isPlacingCommodityOrder = false;

  List<CommodityTradeModel> get commodityOrders => _commodityOrders;
  List<CommodityHoldingModel> get commodityHoldings => _commodityHoldings;
  bool get isLoadingCommodityOrders => _isLoadingCommodityOrders;
  bool get isPlacingCommodityOrder => _isPlacingCommodityOrder;

  Future<void> loadCommodityOrders() async {
    _isLoadingCommodityOrders = true;
    notifyListeners();
    try {
      _commodityOrders = await _api.getPaperCommodityOrders();
      _commodityHoldings = await _api.getPaperCommodityHoldings();
    } catch (_) {}
    _isLoadingCommodityOrders = false;
    notifyListeners();
  }

  Future<CommodityTradeModel?> placeCommodityOrder({
    required String commodityId,
    required String side,
    required int quantity,
  }) async {
    _isPlacingCommodityOrder = true;
    _error = null;
    notifyListeners();
    try {
      final order = await _api.placePaperCommodityOrder(
        commodityId: commodityId, side: side, quantity: quantity,
      );
      _commodityOrders = [order, ..._commodityOrders];
      // Refresh holdings immediately so Sell unlocks right after a Buy
      // fills, without needing to close and reopen the trading pad.
      try {
        _commodityHoldings = await _api.getPaperCommodityHoldings();
      } catch (_) {}
      _isPlacingCommodityOrder = false;
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Commodity order failed. Try again.';
    }
    _isPlacingCommodityOrder = false;
    notifyListeners();
    return null;
  }

  Future<bool> exitCommodityPosition(String commodityId) async {
    try {
      await _api.exitPaperCommodityPosition(commodityId);
      await loadCommodityOrders();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not exit commodity position.';
    }
    notifyListeners();
    return false;
  }

  // ─── Unified Paper Portfolio ─────────────────────────────────────────
  // One live view across equity + option + commodity paper positions,
  // all sharing the same PaperWallet.

  PaperPortfolioModel _portfolio = PaperPortfolioModel.empty;
  bool _isLoadingPortfolio = false;

  PaperPortfolioModel get portfolio => _portfolio;
  bool get isLoadingPortfolio => _isLoadingPortfolio;

  Future<void> loadPortfolio() async {
    _isLoadingPortfolio = true;
    notifyListeners();
    try {
      _portfolio = await _api.getPaperPortfolio();
    } catch (_) {}
    _isLoadingPortfolio = false;
    notifyListeners();
  }
}
