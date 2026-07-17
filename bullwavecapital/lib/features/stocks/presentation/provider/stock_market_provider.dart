import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/market_index_model.dart';
import '../../../../models/stock_model.dart';

class StockMarketProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<StockModel> _stocks = [];
  List<StockModel> _watchlistStocks = [];
  List<MarketIndexModel> _marketIndices = [];
  final Set<String> _watchlist = {};
  String _searchQuery = '';
  bool _isLoading = false;
  bool _watchlistLoading = false;
  bool _initialized = false;
  String? _marketError;
  String? _watchlistError;
  String _lastUpdated = '';
  String _marketProvider = '';
  bool _usingDemoData = false;
  final Map<String, List<CandleModel>> _candlesCache = {};
  Timer? _refreshTimer;

  StockMarketProvider() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_initialized && _searchQuery.isEmpty) {
        _refreshLive(silent: true, fast: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get isLoading => _isLoading;
  bool get watchlistLoading => _watchlistLoading;
  bool get isInitialized => _initialized;
  String get searchQuery => _searchQuery;
  String? get marketError => _marketError;
  String? get watchlistError => _watchlistError;
  String get lastUpdated => _lastUpdated;
  String get marketProvider => _marketProvider;
  bool get isUsingDemoData => _usingDemoData;
  Set<String> get watchlistSymbols => _watchlist;
  List<MarketIndexModel> get marketIndices => _marketIndices;

  List<StockModel> get allStocks => _stocks;

  List<StockModel> get searchResults {
    if (_searchQuery.isEmpty) return _stocks;
    final q = _searchQuery.toLowerCase();
    return _stocks
        .where(
          (s) =>
              s.symbol.toLowerCase().contains(q) ||
              s.name.toLowerCase().contains(q) ||
              s.sector.toLowerCase().contains(q),
        )
        .toList();
  }

  List<StockModel> get trendingStocks =>
      List.from(_stocks)..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));

  List<StockModel> get watchlistStocks => List.unmodifiable(_watchlistStocks);

  StockModel? getStock(String symbol) {
    try {
      return _stocks.firstWhere((s) => s.symbol == symbol.toUpperCase());
    } catch (_) {
      try {
        return _watchlistStocks.firstWhere((s) => s.symbol == symbol.toUpperCase());
      } catch (_) {
        return null;
      }
    }
  }

  List<CandleModel> getCandles(String symbol, {String interval = '1d'}) {
    final key = _candleKey(symbol, interval);
    return _candlesCache[key] ?? [];
  }

  static String _candleKey(String symbol, String interval) =>
      '${symbol.toUpperCase()}:$interval';

  TechnicalIndicatorsModel getIndicators(String symbol, {String interval = '1d'}) {
    final candles = getCandles(symbol, interval: interval);
    if (candles.isEmpty) {
      return const TechnicalIndicatorsModel(
        rsi: 50,
        macdSignal: 'Neutral',
        sma50: 0,
        sma200: 0,
        trend: 'Sideways',
      );
    }
    final closes = candles.map((c) => c.close).toList();
    final sma50 = closes.length >= 50
        ? closes.sublist(closes.length - 50).reduce((a, b) => a + b) / 50
        : closes.reduce((a, b) => a + b) / closes.length;
    final sma200 = closes.length >= 200
        ? closes.sublist(closes.length - 200).reduce((a, b) => a + b) / 200
        : closes.reduce((a, b) => a + b) / closes.length;
    final trend = closes.last > sma50
        ? (closes.last > sma200 ? 'Uptrend' : 'Bullish')
        : (closes.last < sma200 ? 'Downtrend' : 'Bearish');
    final rsi = _approxRsi(closes);
    return TechnicalIndicatorsModel(
      rsi: rsi,
      macdSignal: trend.contains('Up') || trend == 'Bullish' ? 'Buy' : 'Sell',
      sma50: sma50,
      sma200: sma200,
      trend: trend,
    );
  }

  double _approxRsi(List<double> closes) {
    if (closes.length < 15) return 50;
    var gains = 0.0;
    var losses = 0.0;
    for (var i = closes.length - 14; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff >= 0) {
        gains += diff;
      } else {
        losses -= diff;
      }
    }
    if (losses == 0) return 70;
    final rs = gains / losses;
    return (100 - (100 / (1 + rs))).clamp(0, 100);
  }

  bool isInWatchlist(String symbol) => _watchlist.contains(symbol.toUpperCase());

  Future<void> ensureLoaded() async {
    if (_initialized && _stocks.isNotEmpty) return;
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    _isLoading = true;
    notifyListeners();

    await _refreshLive(fast: true);
    await _loadWatchlist();

    _isLoading = false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshWatchlist() async {
    _watchlistLoading = true;
    _watchlistError = null;
    notifyListeners();
    await _loadWatchlist();
    _watchlistLoading = false;
    notifyListeners();
  }

  Future<void> _loadWatchlist() async {
    try {
      final watchlist = await _api.getWatchlist();
      _watchlist
        ..clear()
        ..addAll(watchlist.map((s) => s.symbol));
      _watchlistStocks = watchlist;
      _watchlistError = null;
      _mergeStocks(watchlist);
    } on ApiException catch (e) {
      _watchlistError = e.message;
    } catch (_) {
      _watchlistError = 'Could not load watchlist.';
    }
  }

  Future<void> _refreshLive({bool silent = false, bool fast = true}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final live = await _api.getLiveMarket(fast: fast);
      if (live.stocks.isNotEmpty) {
        _stocks = live.stocks;
        _marketError = null;
        _usingDemoData = false;
      }
      if (live.indices.isNotEmpty) {
        _marketIndices = live.indices;
      }
      _lastUpdated = live.updatedAt;
      _marketProvider = live.provider;
      if (_stocks.isEmpty) {
        await _trySearchFallback();
      }
      if (_watchlistStocks.isNotEmpty) {
        _mergeStocks(_watchlistStocks);
      }
    } on ApiException catch (e) {
      if (_stocks.isEmpty) {
        _marketError = e.message;
        await _trySearchFallback();
      }
    } catch (_) {
      if (_stocks.isEmpty) {
        _marketError = 'Could not load live market data. Pull to refresh.';
        await _trySearchFallback();
      }
    }
    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> _trySearchFallback() async {
    if (_stocks.isNotEmpty) return;
    try {
      final fallback = await _api.searchStocks(live: false);
      if (fallback.isNotEmpty) {
        _stocks = fallback;
        _marketError = null;
        _usingDemoData = false;
        return;
      }
    } catch (_) {}

    _marketError ??= 'Live market data unavailable. Check backend is running and pull to refresh.';
    _usingDemoData = false;
  }

  void _mergeStocks(List<StockModel> incoming) {
    final map = {for (final s in _stocks) s.symbol: s};
    for (final s in incoming) {
      map[s.symbol] = s;
    }
    _stocks = map.values.toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();

    if (query.length >= 2) {
      _api.searchStocks(query: query).then((results) {
        _stocks = results;
        _marketError = null;
        notifyListeners();
      }).catchError((_) {});
    } else if (query.isEmpty) {
      _refreshLive(silent: true, fast: true);
    }
  }

  Future<String?> toggleWatchlist(String symbol) async {
    final s = symbol.toUpperCase();
    final wasIn = _watchlist.contains(s);
    StockModel? removedStock;

    if (wasIn) {
      _watchlist.remove(s);
      for (final st in _watchlistStocks) {
        if (st.symbol == s) {
          removedStock = st;
          break;
        }
      }
      _watchlistStocks.removeWhere((st) => st.symbol == s);
    } else {
      _watchlist.add(s);
      final stock = getStock(s);
      if (stock != null && !_watchlistStocks.any((st) => st.symbol == s)) {
        _watchlistStocks = [..._watchlistStocks, stock];
      }
    }
    notifyListeners();

    try {
      if (wasIn) {
        await _api.removeFromWatchlist(s);
      } else {
        final added = await _api.addToWatchlist(s);
        if (added != null) {
          _mergeStocks([added]);
          final idx = _watchlistStocks.indexWhere((st) => st.symbol == s);
          if (idx >= 0) {
            _watchlistStocks[idx] = added;
          } else {
            _watchlistStocks = [..._watchlistStocks, added];
          }
        } else {
          await _loadWatchlist();
        }
      }
      _watchlistError = null;
      return null;
    } on ApiException catch (e) {
      if (wasIn) {
        _watchlist.add(s);
        if (removedStock != null && !_watchlistStocks.any((st) => st.symbol == s)) {
          _watchlistStocks = [..._watchlistStocks, removedStock];
        }
      } else {
        _watchlist.remove(s);
        _watchlistStocks.removeWhere((st) => st.symbol == s);
      }
      notifyListeners();
      return e.message;
    } catch (_) {
      if (wasIn) {
        _watchlist.add(s);
        if (removedStock != null && !_watchlistStocks.any((st) => st.symbol == s)) {
          _watchlistStocks = [..._watchlistStocks, removedStock];
        }
      } else {
        _watchlist.remove(s);
        _watchlistStocks.removeWhere((st) => st.symbol == s);
      }
      notifyListeners();
      return 'Could not update watchlist.';
    }
  }

  Future<void> loadCandles(String symbol, {String interval = '1d'}) async {
    final key = _candleKey(symbol, interval);
    try {
      final cached = await _api.getCandles(symbol, interval: interval, fast: true);
      if (cached.isNotEmpty) {
        _candlesCache[key] = cached;
        notifyListeners();
      }
      final fresh = await _api.getCandles(symbol, interval: interval);
      if (fresh.isNotEmpty) {
        _candlesCache[key] = fresh;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<StockModel?> ensureStock(String symbol) async {
    final upper = symbol.toUpperCase();
    final existing = getStock(upper);
    if (existing != null) return existing;

    try {
      final stock = await _api.getStockQuote(upper);
      _stocks = [..._stocks.where((s) => s.symbol != upper), stock];
      notifyListeners();
      return stock;
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    await _loadInitial();
  }
}

