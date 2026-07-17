import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../models/portfolio_model.dart';

class PortfolioProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  bool _isLoading = true;
  PortfolioModel _portfolio = const PortfolioModel(
    totalInvestment: 0,
    currentValue: 0,
    monthlyProfit: 0,
    totalProfit: 0,
    growthPercent: 0,
  );
  List<AllocationItem> _allocations = [];
  List<MonthlyEarning> _monthlyEarnings = [];

  bool get isLoading => _isLoading;
  PortfolioModel get portfolio => _portfolio;
  List<AllocationItem> get allocations => _allocations;
  List<MonthlyEarning> get monthlyEarnings => _monthlyEarnings;

  PortfolioProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _portfolio = await _api.getPortfolio();
      _allocations = await _api.getAllocations();
      _monthlyEarnings = await _api.getEarnings();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
