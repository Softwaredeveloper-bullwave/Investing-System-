import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../models/investment_model.dart';

class InvestmentProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  double _investmentAmount = 1000000;
  bool _isLoading = false;
  List<FaqItem> _faqs = [];
  InvestmentPlanModel? _plan;
  List<InvestmentPlanModel> _plans = [];

  double get investmentAmount => _investmentAmount;
  bool get isLoading => _isLoading;
  List<FaqItem> get faqs => _faqs;
  InvestmentPlanModel get plan =>
      _plan ??
      const InvestmentPlanModel(
        id: 'PLAN001',
        name: 'BullWave Alpha Premier',
        minimumInvestment: 1000000,
        monthlyReturnRate: 0.25,
        monthlyReturnMin: 0.25,
        monthlyReturnMax: 0.25,
        annualReturnRate: 3,
        description: '',
      );

  double get expectedMonthlyReturn =>
      _investmentAmount * (plan.monthlyReturnRate / 100);

  double get estimatedAnnualReturn =>
      _investmentAmount * (plan.annualReturnRate / 100);

  InvestmentProvider() {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      _plans = await _api.getInvestmentPlans();
      _plan = _plans.isNotEmpty ? _plans.first : null;
      if (_plan != null) _investmentAmount = _plan!.minimumInvestment;
      final faqData = await _api.getInvestmentFaqs();
      _faqs = faqData;
      notifyListeners();
    } catch (_) {}
  }

  void setPlan(InvestmentPlanModel plan) {
    _plan = plan;
    _investmentAmount = plan.minimumInvestment;
    notifyListeners();
  }

  void setInvestmentAmount(double value) {
    _investmentAmount = value;
    notifyListeners();
  }

  void toggleFaq(int index) {
    _faqs[index] = _faqs[index].copyWith(
      isExpanded: !_faqs[index].isExpanded,
    );
    notifyListeners();
  }

  Future<bool> invest() async {
    if (_plan == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _api.subscribeInvestment(
        planId: _plan!.id,
        amount: _investmentAmount,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
