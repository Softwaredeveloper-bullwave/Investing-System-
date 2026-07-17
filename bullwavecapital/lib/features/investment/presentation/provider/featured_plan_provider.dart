import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/investment_model.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../data/featured_plans_catalog.dart';

class FeaturedPlanProvider extends ChangeNotifier {
  FeaturedPlanProvider({
    required this.planId,
    InvestmentPlanModel? initialPlan,
  }) : plan = initialPlan ?? FeaturedPlansCatalog.findById(planId);

  final String planId;
  final _api = BullwaveApi.instance;

  InvestmentPlanModel? plan;
  double investmentAmount = 1000000;
  double walletBalance = 0;
  bool isLoading = true;
  bool isPaying = false;
  String? error;
  String paymentMethod = 'UPI';

  double get minMonthlyReturn =>
      investmentAmount * ((plan?.monthlyReturnRate ?? plan?.monthlyReturnMin ?? 0) / 100);

  double get maxMonthlyReturn => plan != null && plan!.hasFixedMonthlyReturn
      ? minMonthlyReturn
      : investmentAmount * ((plan?.monthlyReturnMax ?? plan?.monthlyReturnRate ?? 0) / 100);
  double get shortfall => (investmentAmount - walletBalance).clamp(0, double.infinity);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final fetched = await _api.getInvestmentPlan(planId);
      plan = fetched;
      investmentAmount = fetched.minimumInvestment;
    } on ApiException catch (e) {
      plan ??= FeaturedPlansCatalog.findById(planId);
      if (plan != null) {
        investmentAmount = plan!.minimumInvestment;
        error = null;
      } else {
        error = e.message;
      }
    } catch (_) {
      plan ??= FeaturedPlansCatalog.findById(planId);
      if (plan != null) {
        investmentAmount = plan!.minimumInvestment;
        error = null;
      } else {
        error = 'Could not load investment plan. Check your connection and try again.';
      }
    }

    try {
      final wallet = await _api.getWallet();
      walletBalance = wallet.balance;
    } catch (_) {
      walletBalance = 0;
    }

    isLoading = false;
    notifyListeners();
  }

  void setAmount(double value) {
    investmentAmount = value;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    paymentMethod = method;
    notifyListeners();
  }

  Future<String?> payAndInvest(KycFlowProvider kycFlow) async {
    if (plan == null) return null;
    if (investmentAmount < plan!.minimumInvestment) {
      error = 'Minimum investment is ${plan!.minimumInvestment.toStringAsFixed(0)}.';
      notifyListeners();
      return null;
    }

    isPaying = true;
    error = null;
    notifyListeners();

    try {
      if (shortfall > 0) {
        final session = await kycFlow.createPayment(shortfall);
        if (session == null) {
          error = kycFlow.error ?? 'Payment could not be started.';
          isPaying = false;
          notifyListeners();
          return null;
        }
        if (session.devMode && session.success) {
          await _api.deposit(shortfall);
        } else if (!session.devMode) {
          isPaying = false;
          notifyListeners();
          return 'Complete payment of ₹${shortfall.toStringAsFixed(0)} via $paymentMethod, then tap Pay & Invest again.';
        } else {
          error = 'Payment was not completed.';
          isPaying = false;
          notifyListeners();
          return null;
        }
        final wallet = await _api.getWallet();
        walletBalance = wallet.balance;
      }

      if (walletBalance < investmentAmount) {
        error = 'Insufficient wallet balance. Add ₹${shortfall.toStringAsFixed(0)} to continue.';
        isPaying = false;
        notifyListeners();
        return null;
      }

      await _api.subscribeInvestment(planId: plan!.id, amount: investmentAmount);
      isPaying = false;
      notifyListeners();
      return 'Investment of ₹${investmentAmount.toStringAsFixed(0)} confirmed!';
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not complete investment.';
    }
    isPaying = false;
    notifyListeners();
    return null;
  }
}
