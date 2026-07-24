import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/widgets/wavy_text.dart';
import '../../../../models/stock_model.dart';
import '../../../../models/portfolio_health_model.dart';

class _SymbolOptionChain {
  List<OptionContractModel> contracts = [];
  double underlying = 0;
  List<String> expiries = [];
  String selectedExpiry = '';
  String? error;
  bool loading = false;
}

class StockFeaturesProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<StockNewsModel> _news = [];
  List<PriceAlertModel> _alerts = [];
  List<NewsAlertModel> _newsAlerts = [];
  List<SipPlanModel> _sipPlans = [];
  List<PaperTradeModel> _paperTrades = [];
  String? _tradeError;
  double? _virtualBalance;
  double? _virtualStartingBalance;
  bool _isResettingPaper = false;
  List<DividendModel> _dividends = [];
  List<ScreenerStockModel> _screenerResults = [];
  List<String> _screenerSectors = ['All'];
  List<IpoEventModel> _ipoEvents = [];
  List<IpoHoldingModel> _ipoHoldings = [];
  List<IpoTradeModel> _ipoTrades = [];
  String? _ipoTradeError;
  bool _isIpoLoading = false;
  final Map<String, _SymbolOptionChain> _optionChains = {};
  List<AiMessageModel> _aiMessages = [];
  List<String> _aiSuggestions = [
    'Should I buy RELIANCE?',
    'Explain RSI indicator',
    'Best IT stocks today?',
    'Nifty outlook this week',
  ];
  String _screenerSector = 'All';
  bool _isLoading = false;
  bool _isNewsLoading = false;
  bool _isScreenerLoading = false;
  bool _isAiLoading = false;
  String? _aiError;
  bool _usingDemoNews = false;

  _SymbolOptionChain _chainState(String symbol) =>
      _optionChains.putIfAbsent(symbol.toUpperCase(), () => _SymbolOptionChain());

  List<StockNewsModel> get news => _news;
  List<PriceAlertModel> get alerts => _alerts;
  List<NewsAlertModel> get newsAlerts => _newsAlerts;
  List<SipPlanModel> get sipPlans => _sipPlans;
  List<PaperTradeModel> get paperTrades => _paperTrades;
  String? get tradeError => _tradeError;
  double? get virtualBalance => _virtualBalance;
  double? get virtualStartingBalance => _virtualStartingBalance;
  bool get isResettingPaper => _isResettingPaper;
  List<DividendModel> get dividends => _dividends;
  List<AiMessageModel> get aiMessages => _aiMessages;
  List<String> get aiSuggestions => _aiSuggestions;
  bool get isAiLoading => _isAiLoading;
  String? get aiError => _aiError;
  bool get isUsingDemoNews => _usingDemoNews;
  String get screenerSector => _screenerSector;
  bool get isLoading => _isLoading;
  bool get isNewsLoading => _isNewsLoading;
  bool get isScreenerLoading => _isScreenerLoading;

  List<ScreenerStockModel> get screenerResults => _screenerResults;
  List<String> get sectors => _screenerSectors;
  List<IpoEventModel> get ipoEvents => _ipoEvents;
  List<IpoHoldingModel> get ipoHoldings => _ipoHoldings;
  List<IpoTradeModel> get ipoTrades => _ipoTrades;
  String? get ipoTradeError => _ipoTradeError;
  bool get isIpoLoading => _isIpoLoading;

  List<IpoEventModel> get featuredIpos =>
      _ipoEvents.where((e) => e.isOpen || e.isUpcoming).take(3).toList();

  IpoHoldingModel? ipoHoldingFor(String ipoId) {
    for (final h in _ipoHoldings) {
      if (h.ipoId == ipoId) return h;
    }
    return null;
  }

  List<OptionContractModel> optionChain(String symbol) => _chainState(symbol).contracts;
  bool isOptionChainLoading(String symbol) => _chainState(symbol).loading;
  String? optionChainError(String symbol) => _chainState(symbol).error;
  double optionUnderlying(String symbol) => _chainState(symbol).underlying;
  List<String> optionExpiries(String symbol) => _chainState(symbol).expiries;
  String optionSelectedExpiry(String symbol) => _chainState(symbol).selectedExpiry;

  StockFeaturesProvider() {
    loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadNews(),
        _loadAlerts(),
        _loadSip(),
        _loadPaperTrades(),
        _loadDividends(),
        _loadScreener(),
      ]);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadNews() async {
    try {
      _news = await _api.getStockNews();
      _usingDemoNews = false;
    } catch (_) {
      if (_news.isEmpty) {
        _usingDemoNews = false;
      }
    }
  }

  Future<void> refreshNews() async {
    _isNewsLoading = true;
    notifyListeners();
    try {
      _news = await _api.getStockNews();
      _usingDemoNews = false;
    } catch (_) {
      if (_news.isEmpty) {
        _usingDemoNews = false;
      }
    }
    _isNewsLoading = false;
    notifyListeners();
  }

  Future<void> _loadAlerts() async => _alerts = await _api.getPriceAlerts();
  Future<void> _loadSip() async => _sipPlans = await _api.getSipPlans();
  Future<void> _loadPaperTrades() async => _paperTrades = await _api.getPaperTrades();
  Future<void> _loadDividends() async {
    try {
      _dividends = await _api.getDividends(sync: true);
    } catch (_) {}
  }

  Future<void> refreshDividends() async {
    try {
      _dividends = await _api.getDividends(sync: true);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadScreener() async {
    final data = await _api.getScreener(
      sector: _screenerSector == 'All' ? null : _screenerSector,
    );
    _screenerResults = data.results;
    _screenerSectors = ['All', ...data.sectors];
  }

  Future<void> refreshScreener() async {
    _isScreenerLoading = true;
    notifyListeners();
    try {
      await _loadScreener();
    } catch (_) {}
    _isScreenerLoading = false;
    notifyListeners();
  }

  void _applyChain(_SymbolOptionChain state, OptionChainResponse chain) {
    state.contracts = chain.contracts;
    state.underlying = chain.underlyingValue;
    state.expiries = chain.expiryDates;
    state.selectedExpiry = chain.selectedExpiry;
  }

  Future<void> loadOptionChain(String symbol, {String? expiry}) async {
    final state = _chainState(symbol);
    state.loading = true;
    state.error = null;
    notifyListeners();

    try {
      // Fast path — show chain immediately from cached/fallback spot.
      try {
        final fast = await _api.getOptionChain(symbol, expiry: expiry, fast: true);
        if (fast.underlyingValue > 0 || fast.contracts.isNotEmpty) {
          _applyChain(state, fast);
          state.error = null;
          notifyListeners();
        }
      } catch (_) {}

      final chain = await _api.getOptionChain(symbol, expiry: expiry);
      if (chain.contracts.isEmpty) {
        state.error = 'No F&O contracts available for ${symbol.toUpperCase()}';
      } else {
        _applyChain(state, chain);
        state.error = null;
      }
    } on ApiException catch (e) {
      if (state.contracts.isEmpty) {
        if (e.statusCode == 403 &&
            e.message.toLowerCase().contains('f&o')) {
          state.error = '__fno_required__';
        } else {
          state.error = e.message;
        }
      }
    } catch (_) {
      if (state.contracts.isEmpty) {
        state.error = 'Could not load F&O chain. Check that Django is running on port 8000.';
      }
    }

    state.loading = false;
    notifyListeners();
  }

  void setScreenerSector(String sector) {
    _screenerSector = sector;
    refreshScreener();
  }

  Future<void> refreshAlerts() async {
    try {
      final results = await Future.wait([
        _api.getPriceAlerts(),
        _api.getNewsAlerts(),
      ]);
      _alerts = results[0] as List<PriceAlertModel>;
      _newsAlerts = results[1] as List<NewsAlertModel>;
      notifyListeners();
    } catch (_) {
      try {
        _alerts = await _api.getPriceAlerts();
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<bool> addNewsAlert(String keyword) async {
    final k = keyword.trim().toUpperCase();
    if (k.isEmpty) return false;
    try {
      final created = await _api.createNewsAlert(k);
      _newsAlerts = [created, ..._newsAlerts.where((a) => a.id != created.id)];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleNewsAlert(String id) async {
    final index = _newsAlerts.indexWhere((a) => a.id == id);
    if (index < 0) return;
    final alert = _newsAlerts[index];
    final next = !alert.isActive;
    try {
      final updated = await _api.updateNewsAlert(id, isActive: next);
      _newsAlerts = [..._newsAlerts];
      _newsAlerts[index] = updated;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNewsAlert(String id) async {
    try {
      await _api.deleteNewsAlert(id);
      _newsAlerts = _newsAlerts.where((a) => a.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshSipPlans() async {
    try {
      _sipPlans = await _api.getSipPlans();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addAlert({
    required String symbol,
    required double targetPrice,
    required String condition,
  }) async {
    try {
      final created = await _api.createPriceAlert(
        symbol: symbol,
        targetPrice: targetPrice,
        condition: condition.toLowerCase(),
      );
      _alerts = [created, ..._alerts];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleAlert(String id) async {
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index < 0) return;
    final alert = _alerts[index];
    final next = !alert.isActive;
    try {
      final updated = await _api.updatePriceAlert(id, isActive: next);
      _alerts = [..._alerts];
      _alerts[index] = updated;
      notifyListeners();
    } catch (_) {
      _alerts[index] = PriceAlertModel(
        id: alert.id,
        symbol: alert.symbol,
        name: alert.name,
        targetPrice: alert.targetPrice,
        condition: alert.condition,
        isActive: next,
      );
      notifyListeners();
    }
  }

  Future<bool> createSip({
    required String symbol,
    required double monthlyAmount,
    int totalInstallments = 12,
  }) async {
    _tradeError = null;
    try {
      final plan = await _api.createSip(
        symbol: symbol,
        monthlyAmount: monthlyAmount,
        totalInstallments: totalInstallments,
      );
      _sipPlans = [plan, ..._sipPlans];
      notifyListeners();
      return true;
    } catch (e) {
      _tradeError = e is ApiException ? e.message : 'Failed to create SIP. Try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshPaperTrades() async {
    try {
      _paperTrades = await _api.getPaperTrades();
      notifyListeners();
    } catch (_) {}
  }

  /// Loads the learner's virtual practice-capital balance. Safe to call
  /// often — it's cheap and keeps buying-power display accurate.
  Future<void> loadPaperWallet() async {
    try {
      final wallet = await _api.getPaperWallet();
      _virtualBalance = wallet['virtualBalance'];
      _virtualStartingBalance = wallet['virtualStartingBalance'];
      notifyListeners();
    } catch (_) {}
  }

  Future<PaperTradeModel?> placePaperTrade({
    required String symbol,
    required String side,
    required int qty,
  }) async {
    _tradeError = null;
    try {
      final trade = await _api.placePaperTrade(
        symbol: symbol,
        side: side,
        quantity: qty,
      );
      _paperTrades = [trade, ..._paperTrades.where((t) => t.id != trade.id)];
      if (trade.virtualBalance != null) {
        _virtualBalance = trade.virtualBalance;
        _virtualStartingBalance = trade.virtualStartingBalance ?? _virtualStartingBalance;
      }
      notifyListeners();
      return trade;
    } catch (e) {
      _tradeError = e is ApiException ? e.message : 'Order failed. Try again.';
      notifyListeners();
      return null;
    }
  }

  /// Wipes all paper positions/orders and restores starting virtual capital
  /// so a learner can start a clean run. Never touches real money.
  Future<bool> resetPaperPortfolio() async {
    _isResettingPaper = true;
    _tradeError = null;
    notifyListeners();
    try {
      final wallet = await _api.resetPaperPortfolio();
      _virtualBalance = wallet['virtualBalance'];
      _virtualStartingBalance = wallet['virtualStartingBalance'];
      _paperTrades = [];
      _isResettingPaper = false;
      notifyListeners();
      return true;
    } catch (e) {
      _tradeError = e is ApiException ? e.message : 'Could not reset paper portfolio. Try again.';
      _isResettingPaper = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAiChat() async {
    try {
      final history = await _api.getAiHistory();
      if (history.isEmpty) {
        _aiMessages = [
          AiMessageModel(
            role: 'assistant',
            content:
                'Hi! I\'m $kWavyChatbotName. Ask about your portfolio, stocks, watchlist, wallet, Goal Plans, or how to use any app feature.',
            time: DateTime.now(),
          ),
        ];
      } else {
        _aiMessages = history;
      }
      final suggestions = await _api.getAiSuggestions();
      if (suggestions.isNotEmpty) {
        _aiSuggestions = suggestions;
      }
      _aiError = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearAiChat() async {
    try {
      await _api.clearAiHistory();
      _aiMessages = [
        AiMessageModel(
          role: 'assistant',
          content: 'Chat cleared. Ask about your portfolio, stocks, or any Capital Bullwave feature.',
          time: DateTime.now(),
        ),
      ];
      _aiError = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendAiMessage(String query, {String symbol = ''}) async {
    if (_isAiLoading) return;
    _aiError = null;
    _aiMessages = [
      ..._aiMessages,
      AiMessageModel(role: 'user', content: query, time: DateTime.now()),
    ];
    _isAiLoading = true;
    notifyListeners();
    try {
      final reply = await _api.sendAiMessage(query, symbol: symbol);
      _aiMessages = [
        ..._aiMessages,
        AiMessageModel(role: 'assistant', content: reply, time: DateTime.now()),
      ];
      _aiError = null;
    } on ApiException catch (e) {
      if (_aiMessages.isNotEmpty && _aiMessages.last.role == 'user') {
        _aiMessages = _aiMessages.sublist(0, _aiMessages.length - 1);
      }
      _aiError = e.message;
    } catch (_) {
      if (_aiMessages.isNotEmpty && _aiMessages.last.role == 'user') {
        _aiMessages = _aiMessages.sublist(0, _aiMessages.length - 1);
      }
      _aiError = 'Could not reach AI assistant. Check server connection and API key in backend/.env.';
    }
    _isAiLoading = false;
    notifyListeners();
  }

  Future<void> refreshIpoCalendar({int? limit}) async {
    _isIpoLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _api.getIpoCalendar(limit: limit).then((v) => _ipoEvents = v),
        _api.getIpoHoldings().then((v) => _ipoHoldings = v),
        _api.getIpoTrades().then((v) => _ipoTrades = v),
      ]);
    } catch (_) {}
    _isIpoLoading = false;
    notifyListeners();
  }

  Future<bool> placeIpoOrder({
    required String ipoId,
    required String side,
    int lots = 1,
  }) async {
    _ipoTradeError = null;
    notifyListeners();
    try {
      final trade = await _api.placeIpoOrder(ipoId: ipoId, side: side, lots: lots);
      _ipoTrades = [trade, ..._ipoTrades.where((t) => t.id != trade.id)];
      await Future.wait([
        _api.getIpoHoldings().then((v) => _ipoHoldings = v),
      ]);
      notifyListeners();
      return true;
    } catch (e) {
      _ipoTradeError = e is ApiException ? e.message : 'IPO order failed. Try again.';
      notifyListeners();
      return false;
    }
  }
}
