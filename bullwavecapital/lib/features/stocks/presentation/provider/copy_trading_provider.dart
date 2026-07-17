import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/copy_trading_model.dart';

class CopyTradingProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<CopyTraderModel> _traders = [];
  List<CopySubscriptionModel> _subscriptions = [];
  CopyTraderModel? _selected;
  bool _isLoading = false;
  bool _isDetailLoading = false;
  bool _isSaving = false;
  String? _error;
  String _riskFilter = '';
  String _searchQuery = '';

  List<CopyTraderModel> get traders => _traders;
  List<CopySubscriptionModel> get subscriptions => _subscriptions;
  CopyTraderModel? get selected => _selected;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get riskFilter => _riskFilter;
  String get searchQuery => _searchQuery;

  Future<void> loadTraders({String? risk, String? q}) async {
    _isLoading = true;
    _error = null;
    if (risk != null) _riskFilter = risk;
    if (q != null) _searchQuery = q;
    notifyListeners();
    try {
      _traders = await _api.getCopyTraders(
        risk: _riskFilter.isEmpty ? null : _riskFilter,
        q: _searchQuery.isEmpty ? null : _searchQuery,
      );
    } on ApiException catch (e) {
      _error = e.message;
      _traders = [];
    } catch (_) {
      _error = 'Could not load verified traders.';
      _traders = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSubscriptions() async {
    try {
      _subscriptions = await _api.getCopySubscriptions();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      // Keep prior list on soft failure.
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([loadTraders(), loadSubscriptions()]);
  }

  Future<CopyTraderModel?> loadTraderDetail(String traderId) async {
    _isDetailLoading = true;
    notifyListeners();
    try {
      _selected = await _api.getCopyTrader(traderId);
      return _selected;
    } on ApiException catch (e) {
      _error = e.message;
      _selected = null;
      return null;
    } catch (_) {
      _error = 'Could not load trader details.';
      _selected = null;
      return null;
    } finally {
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  Future<String?> startCopy({
    required String traderId,
    required double allocationInr,
    double copyRatio = 1,
    bool autoCopy = true,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final sub = await _api.startCopyTrading(
        traderId: traderId,
        allocationInr: allocationInr,
        copyRatio: copyRatio,
        autoCopy: autoCopy,
      );
      _subscriptions = [
        sub,
        ..._subscriptions.where((s) => s.trader.id != traderId),
      ];
      _traders = _traders
          .map(
            (t) => t.id == traderId
                ? t.copyWith(
                    isCopying: true,
                    followersCount: t.followersCount + (t.isCopying ? 0 : 1),
                  )
                : t,
          )
          .toList();
      if (_selected?.id == traderId) {
        _selected = _selected!.copyWith(isCopying: true);
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to start copy trading.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> setSubscriptionStatus(String subscriptionId, String status) async {
    _isSaving = true;
    notifyListeners();
    try {
      if (status == 'stopped') {
        await _api.stopCopySubscription(subscriptionId);
        _subscriptions = _subscriptions.where((s) => s.id != subscriptionId).toList();
      } else {
        final updated = await _api.updateCopySubscription(subscriptionId, status: status);
        _subscriptions = _subscriptions
            .map((s) => s.id == subscriptionId ? updated : s)
            .toList();
      }
      await loadTraders();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update copy status.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
