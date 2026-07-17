import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../core/api/json_parsers.dart';
import '../../../../models/goal_plan_model.dart';
import '../../../../models/investment_model.dart';
import '../../../../models/market_index_model.dart';
import '../../../../models/portfolio_model.dart';
import '../../../../models/transaction_model.dart';
import '../../../investment/data/featured_plans_catalog.dart';

class HomeProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  bool _isLoading = true;
  String? _error;
  PortfolioModel _portfolio = const PortfolioModel(
    totalInvestment: 0,
    currentValue: 0,
    monthlyProfit: 0,
    totalProfit: 0,
    growthPercent: 0,
  );
  List<InvestmentPlanModel> _featuredPlans = [];
  List<UserGoalPlanModel> _goalPlans = [];
  List<MarketIndexModel> _marketIndices = [];
  List<Map<String, String>> _marketNews = [];
  List<MonthlyEarning> _monthlyEarnings = [];
  List<TransactionModel> _recentTransactions = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  PortfolioModel get portfolio => _portfolio;
  List<InvestmentPlanModel> get featuredPlans => _featuredPlans;
  List<UserGoalPlanModel> get goalPlans => _goalPlans;
  List<MarketIndexModel> get marketIndices =>
      _marketIndices.isNotEmpty ? _marketIndices : _fallbackMarketIndices;
  List<Map<String, String>> get marketNews => _marketNews;
  List<MonthlyEarning> get monthlyEarnings => _monthlyEarnings;
  List<TransactionModel> get recentTransactions => _recentTransactions;

  /// Chart points for the hero — earnings history or a smooth curve from portfolio value.
  List<double> get portfolioChartValues {
    if (_monthlyEarnings.isNotEmpty) {
      return _monthlyEarnings.map((e) => e.amount).toList();
    }
    final base = _portfolio.currentValue > 0 ? _portfolio.currentValue : _portfolio.walletBalance;
    if (base <= 0) return const [0, 0, 0, 0, 0, 0];
    final drift = _portfolio.dayPnl;
    return List<double>.generate(8, (i) {
      final factor = 0.92 + (i / 8) * 0.08;
      return (base - drift) * factor + (drift * i / 8);
    });
  }

  static const _fallbackMarketIndices = [
    MarketIndexModel(
      id: 'NIFTY50',
      name: 'Nifty 50',
      shortName: 'NIFTY',
      value: 24832.45,
      change: 156.30,
      changePercent: 0.63,
    ),
    MarketIndexModel(
      id: 'SENSEX',
      name: 'Sensex',
      shortName: 'SENSEX',
      value: 81524.78,
      change: 582.15,
      changePercent: 0.72,
    ),
    MarketIndexModel(
      id: 'BANKNIFTY',
      name: 'Bank Nifty',
      shortName: 'BANK NIFTY',
      value: 52318.60,
      change: -124.40,
      changePercent: -0.24,
    ),
  ];

  HomeProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final home = await _api.getHome();
      _portfolio = parsePortfolio(home['portfolio'] as Map<String, dynamic>? ?? {});
      _featuredPlans = parseList(home['featuredPlans'], parseInvestmentPlan);
      _goalPlans = parseList(home['goalPlans'], parseUserGoalPlan);
      _marketIndices = parseList(home['marketIndices'], parseMarketIndex);
      _marketNews = (home['marketNews'] as List<dynamic>? ?? [])
          .map((e) {
            final m = e as Map;
            return {
              'title': m['title']?.toString() ?? '',
              'subtitle': m['subtitle']?.toString() ?? '',
              'url': m['url']?.toString() ?? '',
              'imageUrl': m['imageUrl']?.toString() ?? m['image_url']?.toString() ?? '',
              'category': m['category']?.toString() ?? 'Markets',
              'time': m['time']?.toString() ?? '',
              'source': m['source']?.toString() ?? '',
            };
          })
          .where((item) => (item['title'] ?? '').trim().isNotEmpty)
          .toList();

      final activity = home['recentActivity'];
      if (activity is List && activity.isNotEmpty) {
        _recentTransactions = parseList(activity, parseTransaction);
      } else {
        try {
          final txns = await _api.getTransactions();
          _recentTransactions = txns.take(5).toList();
        } catch (_) {}
      }
    } catch (_) {
      _error = 'Could not load home data. Pull to refresh.';
    }

    try {
      _monthlyEarnings = await _api.getEarnings();
    } catch (_) {}

    if (_featuredPlans.isEmpty) {
      try {
        final plans = await _api.getInvestmentPlans();
        _featuredPlans = plans.where((p) => p.isFeatured).toList();
      } catch (_) {}
    }

    if (_featuredPlans.isEmpty) {
      _featuredPlans = List.from(FeaturedPlansCatalog.plans);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadData();
}
