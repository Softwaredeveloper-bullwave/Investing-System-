import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/goal_plan_model.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../data/goal_return_tiers.dart';
import '../../data/goal_templates_catalog.dart';

class GoalPlanProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<GoalTemplateModel> templates = GoalTemplatesCatalog.templates;
  List<GoalReturnTierModel> returnTiers = GoalReturnTiersDefaults.tiers;
  List<UserGoalPlanModel> goals = [];
  List<UserGoalPlanModel> dueGoals = [];
  double walletBalance = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  String? error;

  GoalTemplateModel? selectedTemplate;
  String title = '';
  double targetAmount = 50000;
  double monthlyContribution = 5000;
  int durationMonths = 12;
  String paymentMethod = 'UPI';

  double get selectedAnnualRate =>
      GoalReturnTiersCatalog.annualRateForMonthly(monthlyContribution);

  GoalReturnTierModel get selectedTier =>
      GoalReturnTiersCatalog.tierForMonthly(monthlyContribution);

  double get shortfall =>
      (monthlyContribution - walletBalance).clamp(0, double.infinity);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final bundle = await _api.getGoalTemplates();
      if (bundle.templates.isNotEmpty) templates = bundle.templates;
      if (bundle.returnTiers.isNotEmpty) returnTiers = bundle.returnTiers;
      goals = await _api.getGoalPlans();
      final reminders = await _api.getGoalReminders();
      dueGoals = reminders.due;
      final wallet = await _api.getWallet();
      walletBalance = wallet.balance;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load goal plans.';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshReminders() async {
    try {
      final reminders = await _api.getGoalReminders();
      dueGoals = reminders.due;
      notifyListeners();
    } catch (_) {}
  }

  void selectTemplate(GoalTemplateModel template) {
    selectedTemplate = template;
    title = template.name;
    targetAmount = template.minTarget;
    monthlyContribution = template.suggestedMonthly;
    durationMonths = 12;
    notifyListeners();
  }

  void setTitle(String v) {
    title = v;
    notifyListeners();
  }

  void setTargetAmount(double v) {
    targetAmount = v;
    notifyListeners();
  }

  void setMonthlyContribution(double v) {
    monthlyContribution = v;
    notifyListeners();
  }

  void setDurationMonths(int v) {
    durationMonths = v;
    notifyListeners();
  }

  void setPaymentMethod(String v) {
    paymentMethod = v;
    notifyListeners();
  }

  Future<String?> startGoal(KycFlowProvider kycFlow) async {
    if (selectedTemplate == null) return null;
    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      if (shortfall > 0) {
        final session = await kycFlow.createPayment(shortfall);
        if (session == null) {
          error = kycFlow.error ?? 'Payment could not be started.';
          isSubmitting = false;
          notifyListeners();
          return null;
        }
        if (session.devMode && session.success) {
          await _api.deposit(shortfall);
        } else if (!session.devMode) {
          isSubmitting = false;
          notifyListeners();
          return 'Complete payment of ₹${shortfall.toStringAsFixed(0)}, then tap Start Goal again.';
        } else {
          error = 'Payment was not completed.';
          isSubmitting = false;
          notifyListeners();
          return null;
        }
        final wallet = await _api.getWallet();
        walletBalance = wallet.balance;
      }

      if (walletBalance < monthlyContribution) {
        error = 'Add ₹${shortfall.toStringAsFixed(0)} to wallet for first installment.';
        isSubmitting = false;
        notifyListeners();
        return null;
      }

      final goal = await _api.createGoalPlan(
        category: selectedTemplate!.category,
        title: title.trim().isEmpty ? selectedTemplate!.name : title.trim(),
        targetAmount: targetAmount,
        monthlyContribution: monthlyContribution,
        durationMonths: durationMonths,
      );
      goals = [goal, ...goals.where((g) => g.id != goal.id)];
      isSubmitting = false;
      notifyListeners();
      return 'Goal started! ₹${monthlyContribution.toStringAsFixed(0)} saved for ${goal.title}.';
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not start goal plan.';
    }
    isSubmitting = false;
    notifyListeners();
    return null;
  }

  Future<String?> payDueInstallment(String goalId, KycFlowProvider kycFlow) async {
    final goal = goals.firstWhere((g) => g.id == goalId);
    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      final need = (goal.monthlyContribution - walletBalance)
          .clamp(0, double.infinity)
          .toDouble();
      if (need > 0) {
        final session = await kycFlow.createPayment(need);
        if (session == null) {
          error = kycFlow.error ?? 'Payment failed.';
          isSubmitting = false;
          notifyListeners();
          return null;
        }
        if (session.devMode && session.success) {
          await _api.deposit(need);
        } else if (!session.devMode) {
          isSubmitting = false;
          notifyListeners();
          return 'Complete payment, then tap Pay Installment again.';
        }
        walletBalance = (await _api.getWallet()).balance;
      }

      final updated = await _api.contributeToGoal(goalId);
      goals = goals.map((g) => g.id == updated.id ? updated : g).toList();
      dueGoals = dueGoals.where((g) => g.id != goalId).toList();
      isSubmitting = false;
      notifyListeners();
      return 'Installment paid for ${updated.title}!';
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not pay installment.';
    }
    isSubmitting = false;
    notifyListeners();
    return null;
  }

  Future<String?> withdrawGoal(String goalId) async {
    isSubmitting = true;
    error = null;
    notifyListeners();
    try {
      final updated = await _api.withdrawFromGoal(goalId);
      goals = goals.map((g) => g.id == updated.id ? updated : g).toList();
      walletBalance = (await _api.getWallet()).balance;
      isSubmitting = false;
      notifyListeners();
      return 'Withdrawn to wallet successfully.';
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Withdrawal failed.';
    }
    isSubmitting = false;
    notifyListeners();
    return null;
  }
}
