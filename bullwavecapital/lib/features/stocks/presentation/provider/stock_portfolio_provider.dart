import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/api/json_parsers.dart';
import '../../../../models/paper_competition_model.dart';
import '../../../../models/portfolio_model.dart';
import '../../../../models/stock_model.dart';

class StockPortfolioProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<StockHoldingModel> _holdings = [];
  List<PaperTradeModel> _recentTrades = [];
  PortfolioSummaryModel _summary = PortfolioSummaryModel.empty;
  List<SectorAllocationItem> _sectorAllocation = [];
  PaperRiskMeterModel? _marketRiskMeter;
  bool _riskLoading = false;
  bool _isLoading = false;
  String? _error;
  DateTime? _updatedAt;

  bool get isLoading => _isLoading;
  bool get riskLoading => _riskLoading;
  String? get error => _error;
  List<StockHoldingModel> get holdings => _holdings;
  List<PaperTradeModel> get recentTrades => _recentTrades;
  PortfolioSummaryModel get summary => _summary;
  List<SectorAllocationItem> get sectorAllocation => _sectorAllocation;
  PaperRiskMeterModel? get marketRiskMeter => _marketRiskMeter;
  DateTime? get updatedAt => _updatedAt;

  double get totalInvested => _summary.totalInvested;
  double get totalCurrentValue => _summary.currentValue;
  double get totalPnl => _summary.totalPnl;
  double get totalPnlPercent => _summary.totalPnlPercent;
  double get dayPnl => _summary.dayPnl;
  double get dayPnlPercent => _summary.dayPnlPercent;
  int get holdingsCount => _summary.holdingsCount;

  /// Fast reload when opening Portfolio tab or after login.
  Future<void> ensureLoaded({bool refreshQuotes = false}) =>
      loadPortfolio(refreshQuotes: refreshQuotes);

  Future<void> loadPortfolio({bool refreshQuotes = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.getPortfolioOverview(refreshQuotes: refreshQuotes);
      _applyPortfolioPayload(data);
      unawaited(loadMarketRiskMeter());
    } on ApiException catch (e) {
      await _tryHoldingsFallback(e.message);
    } on TimeoutException {
      await _tryHoldingsFallback('Portfolio load timed out. Showing saved holdings.');
    } on SocketException {
      await _tryHoldingsFallback('Cannot reach server. Showing saved holdings.');
    } catch (e) {
      await _tryHoldingsFallback('Could not load portfolio ($e).');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMarketRiskMeter() async {
    _riskLoading = true;
    notifyListeners();
    try {
      _marketRiskMeter = await _api.getMarketRiskMeter();
    } catch (_) {
      // Soft-fail — Markets can still render without the meter.
    }
    _riskLoading = false;
    notifyListeners();
  }

  Future<void> _tryHoldingsFallback(String message) async {
    if (_holdings.isNotEmpty) {
      _error = message;
      return;
    }
    try {
      final holdings = await _api.getStockHoldings();
      if (holdings.isNotEmpty) {
        _holdings = holdings;
        _recomputeSummaryFromHoldings();
        _error = null;
        return;
      }
    } catch (_) {}
    _error = message;
    _summary = PortfolioSummaryModel.empty;
    _sectorAllocation = [];
    _recentTrades = [];
  }

  void _applyPortfolioPayload(Map<String, dynamic> data) {
    final summaryJson = data['summary'] as Map<String, dynamic>? ?? {};
    _summary = parsePortfolioSummary(summaryJson);
    _holdings = _safeParseList(data['holdings'], parseStockHolding);
    _sectorAllocation = _safeParseList(data['sectorAllocation'], parseSectorAllocation);
    _recentTrades = _safeParseList(data['recentTrades'], parsePaperTrade);
    final updated = data['updatedAt'] as String?;
    _updatedAt = updated != null ? DateTime.tryParse(updated) : DateTime.now();
    _error = null;
  }

  List<T> _safeParseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (raw is! List) return [];
    final items = <T>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        items.add(parser(entry));
      } catch (_) {}
    }
    return items;
  }

  /// Instantly reflect an executed order so sell works without waiting on network.
  void applyExecutedOrder(PaperTradeModel order) {
    final ltp = order.ltp > 0 ? order.ltp : order.price;
    final existingIndex = _holdings.indexWhere((h) => h.symbol == order.symbol);

    if (order.isBuy) {
      final qty = order.holdingQty ?? order.quantity;
      final avg = order.holdingAvgPrice ?? order.price;
      final holding = StockHoldingModel(
        symbol: order.symbol,
        name: order.stockName.isNotEmpty ? order.stockName : order.symbol,
        quantity: qty,
        avgPrice: avg,
        ltp: ltp,
      );
      if (existingIndex >= 0) {
        _holdings[existingIndex] = holding;
      } else {
        _holdings.add(holding);
      }
    } else if (order.isSell) {
      final remaining = order.holdingQty ?? 0;
      if (remaining > 0 && existingIndex >= 0) {
        final prev = _holdings[existingIndex];
        _holdings[existingIndex] = StockHoldingModel(
          symbol: prev.symbol,
          name: prev.name,
          sector: prev.sector,
          exchange: prev.exchange,
          quantity: remaining,
          avgPrice: order.holdingAvgPrice ?? prev.avgPrice,
          ltp: ltp,
          change: prev.change,
          changePercent: prev.changePercent,
          dayPnl: prev.dayPnl,
        );
      } else if (existingIndex >= 0) {
        _holdings.removeAt(existingIndex);
      }
    }

    _recentTrades = [
      order,
      ..._recentTrades.where((t) => t.id != order.id),
    ];
    _recomputeSummaryFromHoldings();
    _error = null;
    notifyListeners();
  }

  void _recomputeSummaryFromHoldings() {
    var invested = 0.0;
    var current = 0.0;
    var day = 0.0;
    for (final h in _holdings) {
      invested += h.invested;
      current += h.currentValue;
      day += h.dayPnl;
    }
    final pnl = current - invested;
    final prev = current - day;
    _summary = PortfolioSummaryModel(
      totalInvested: invested,
      currentValue: current,
      totalPnl: pnl,
      totalPnlPercent: invested == 0 ? 0 : (pnl / invested) * 100,
      dayPnl: day,
      dayPnlPercent: prev == 0 ? 0 : (day / prev) * 100,
      holdingsCount: _holdings.length,
    );
  }

  int holdingQtyFor(String symbol) {
    final match = _holdings.where((h) => h.symbol == symbol);
    if (match.isEmpty) return 0;
    return match.first.quantity;
  }

  StockHoldingModel? holdingFor(String symbol) {
    for (final h in _holdings) {
      if (h.symbol == symbol) return h;
    }
    return null;
  }

  Future<void> loadHoldings({bool refreshQuotes = false}) =>
      loadPortfolio(refreshQuotes: refreshQuotes);
}

extension StockHoldingTradeStock on StockHoldingModel {
  StockModel toTradeStock() => StockModel(
        symbol: symbol,
        name: name,
        exchange: exchange,
        sector: sector,
        ltp: ltp,
        change: change,
        changePercent: changePercent,
        open: ltp,
        high: ltp,
        low: ltp,
        previousClose: ltp,
        volume: 0,
        marketCapCr: 0,
        pe: 0,
        eps: 0,
        week52High: ltp,
        week52Low: ltp,
      );
}
