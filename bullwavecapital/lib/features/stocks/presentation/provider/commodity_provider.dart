import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/commodity_model.dart';
import '../../../../models/stock_model.dart';

class _CommodityOptionState {
  List<OptionContractModel> contracts = [];
  double underlying = 0;
  List<String> expiries = [];
  String selectedExpiry = '';
  bool loading = false;
  String? error;
}

class CommodityProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<CommodityModel> _commodities = [];
  final Map<String, CommodityModel> _detailCache = {};
  List<CommodityHoldingModel> _holdings = [];
  List<CommodityTradeModel> _trades = [];
  final Map<String, _CommodityOptionState> _optionChains = {};
  bool _isLoading = false;
  bool _holdingsLoading = false;
  bool _initialized = false;
  String? _error;
  String? _tradeError;
  String _updatedAt = '';
  String _provider = '';
  bool _usingDemoData = false;
  Timer? _refreshTimer;

  CommodityProvider() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_initialized) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get isLoading => _isLoading;
  bool get holdingsLoading => _holdingsLoading;
  bool get isInitialized => _initialized;
  String? get error => _error;
  String? get tradeError => _tradeError;
  String get updatedAt => _updatedAt;
  String get provider => _provider;
  bool get isUsingDemoData => _usingDemoData;
  List<CommodityModel> get commodities => List.unmodifiable(_commodities);
  List<CommodityHoldingModel> get holdings => List.unmodifiable(_holdings);
  List<CommodityTradeModel> get trades => List.unmodifiable(_trades);

  _CommodityOptionState _chainState(String id) =>
      _optionChains.putIfAbsent(id.toUpperCase(), () => _CommodityOptionState());

  List<OptionContractModel> optionChain(String commodityId) => _chainState(commodityId).contracts;
  double optionUnderlying(String commodityId) => _chainState(commodityId).underlying;
  List<String> optionExpiries(String commodityId) => _chainState(commodityId).expiries;
  String optionSelectedExpiry(String commodityId) => _chainState(commodityId).selectedExpiry;
  bool isOptionChainLoading(String commodityId) => _chainState(commodityId).loading;
  String? optionChainError(String commodityId) => _chainState(commodityId).error;

  Future<void> loadOptionChain(String commodityId, {String? expiry}) async {
    final key = commodityId.toUpperCase();
    final state = _chainState(key);
    state.loading = true;
    state.error = null;
    notifyListeners();

    try {
      try {
        final fast = await _api.getCommodityOptionChain(key, expiry: expiry, fast: true);
        if (fast.contracts.isNotEmpty) {
          _applyChain(state, fast);
          notifyListeners();
        }
      } catch (_) {}

      final chain = await _api.getCommodityOptionChain(key, expiry: expiry);
      if (chain.contracts.isEmpty) {
        state.error = 'No option contracts for $key';
      } else {
        _applyChain(state, chain);
        state.error = null;
      }
    } on ApiException catch (e) {
      if (state.contracts.isEmpty) state.error = e.message;
    } catch (_) {
      if (state.contracts.isEmpty) {
        state.error = 'Could not load commodity options. Is the backend running?';
      }
    }

    state.loading = false;
    notifyListeners();
  }

  void _applyChain(_CommodityOptionState state, OptionChainResponse chain) {
    state.contracts = chain.contracts;
    state.underlying = chain.underlyingValue;
    state.expiries = chain.expiryDates;
    state.selectedExpiry = chain.selectedExpiry;
  }

  CommodityModel? commodityById(String id) {
    final key = id.toUpperCase();
    if (_detailCache.containsKey(key)) return _detailCache[key];
    for (final c in _commodities) {
      if (c.id == key) return c;
    }
    return null;
  }

  CommodityHoldingModel? holdingFor(String commodityId) {
    final key = commodityId.toUpperCase();
    try {
      return _holdings.firstWhere((h) => h.commodityId == key);
    } catch (_) {
      return null;
    }
  }

  int holdingQtyFor(String commodityId) => holdingFor(commodityId)?.quantity ?? 0;

  List<CommodityModel> commoditiesByCategory(String category) =>
      _commodities.where((c) => c.category == category).toList();

  List<String> get categories =>
      _commodities.map((c) => c.category).toSet().toList();

  Future<void> ensureLoaded() async {
    if (_initialized || _isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    await Future.wait([_load(), loadHoldings()]);
  }

  Future<CommodityModel?> loadDetail(String commodityId) async {
    final key = commodityId.toUpperCase();
    final cached = commodityById(key);
    if (cached != null && cached.ltp > 0) return cached;
    try {
      final detail = await _api.getCommodityDetail(key);
      _detailCache[key] = detail;
      final index = _commodities.indexWhere((c) => c.id == key);
      if (index >= 0) {
        _commodities = [..._commodities];
        _commodities[index] = detail;
      }
      notifyListeners();
      return detail;
    } catch (_) {
      return cached;
    }
  }

  Future<void> loadHoldings() async {
    _holdingsLoading = true;
    notifyListeners();
    try {
      _holdings = await _api.getCommodityHoldings();
    } catch (_) {}
    _holdingsLoading = false;
    notifyListeners();
  }

  Future<CommodityTradeModel?> placeOrder({
    required String commodityId,
    required String side,
    required int quantity,
  }) async {
    _tradeError = null;
    try {
      final trade = await _api.placeCommodityOrder(
        commodityId: commodityId,
        side: side,
        quantity: quantity,
      );
      _trades = [trade, ..._trades.where((t) => t.id != trade.id)];
      await loadHoldings();
      notifyListeners();
      return trade;
    } catch (e) {
      _tradeError = e is ApiException ? e.message : 'Order failed. Try again.';
      notifyListeners();
      return null;
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final snapshot = await _api.getCommodities();
      _commodities = snapshot.commodities;
      _updatedAt = snapshot.updatedAt;
      _provider = snapshot.provider;
      for (final row in _commodities) {
        _detailCache[row.id] = row;
      }
      _error = null;
      _usingDemoData = false;
      _initialized = true;
    } on ApiException catch (e) {
      if (_commodities.isEmpty) {
        _error = e.message;
        _usingDemoData = false;
      }
    } catch (_) {
      if (_commodities.isEmpty) {
        _error = 'Unable to load commodity prices. Is Django running on port 8000?';
        _usingDemoData = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
