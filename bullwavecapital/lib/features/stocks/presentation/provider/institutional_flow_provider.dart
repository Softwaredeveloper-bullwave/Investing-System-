import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/institutional_flow_model.dart';

class InstitutionalFlowProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<BlockDealModel> _blockDeals = [];
  BlockDealSummary _blockSummary = const BlockDealSummary(
    buyValueCr: 0,
    sellValueCr: 0,
    netValueCr: 0,
    blockCount: 0,
    bulkCount: 0,
  );
  List<DarkPoolPrintModel> _darkPrints = [];
  DarkPoolSummary _darkSummary = const DarkPoolSummary(
    totalValueCr: 0,
    buyBiased: 0,
    sellBiased: 0,
    avgVsVwap: 0,
  );
  bool _blockLoading = false;
  bool _darkLoading = false;
  String? _blockError;
  String? _darkError;
  String _dealTypeFilter = '';
  String _sideFilter = '';
  String _biasFilter = '';

  List<BlockDealModel> get blockDeals => _blockDeals;
  BlockDealSummary get blockSummary => _blockSummary;
  List<DarkPoolPrintModel> get darkPrints => _darkPrints;
  DarkPoolSummary get darkSummary => _darkSummary;
  bool get blockLoading => _blockLoading;
  bool get darkLoading => _darkLoading;
  String? get blockError => _blockError;
  String? get darkError => _darkError;
  String get dealTypeFilter => _dealTypeFilter;
  String get sideFilter => _sideFilter;
  String get biasFilter => _biasFilter;

  Future<void> loadBlockDeals({String? dealType, String? side}) async {
    if (dealType != null) _dealTypeFilter = dealType;
    if (side != null) _sideFilter = side;
    _blockLoading = true;
    _blockError = null;
    notifyListeners();
    try {
      final res = await _api.getBlockDeals(
        dealType: _dealTypeFilter.isEmpty ? null : _dealTypeFilter,
        side: _sideFilter.isEmpty ? null : _sideFilter,
      );
      _blockDeals = res.deals;
      _blockSummary = res.summary;
    } on ApiException catch (e) {
      _blockError = e.message;
      _blockDeals = [];
    } catch (_) {
      _blockError = 'Could not load block deals.';
      _blockDeals = [];
    }
    _blockLoading = false;
    notifyListeners();
  }

  Future<void> loadDarkPool({String? bias}) async {
    if (bias != null) _biasFilter = bias;
    _darkLoading = true;
    _darkError = null;
    notifyListeners();
    try {
      final res = await _api.getDarkPoolPrints(
        bias: _biasFilter.isEmpty ? null : _biasFilter,
      );
      _darkPrints = res.prints;
      _darkSummary = res.summary;
    } on ApiException catch (e) {
      _darkError = e.message;
      _darkPrints = [];
    } catch (_) {
      _darkError = 'Could not load dark pool prints.';
      _darkPrints = [];
    }
    _darkLoading = false;
    notifyListeners();
  }
}
