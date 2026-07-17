import '../../../models/investment_model.dart';

/// Canonical featured plan tiers — used as offline fallback when API is unavailable.
class FeaturedPlansCatalog {
  FeaturedPlansCatalog._();

  static const plans = [
    InvestmentPlanModel(
      id: 'PLAN001',
      name: 'BullWave Alpha Premier',
      minimumInvestment: 1000000,
      monthlyReturnRate: 0.25,
      monthlyReturnMin: 0.25,
      monthlyReturnMax: 0.25,
      annualReturnRate: 3,
      description:
          'Entry-tier premium plan for disciplined investors. Commit ₹10,00,000 and receive 0.25% monthly returns.',
      isFeatured: true,
    ),
    InvestmentPlanModel(
      id: 'PLAN002',
      name: 'BullWave Platinum Reserve',
      minimumInvestment: 5000000,
      monthlyReturnRate: 3,
      monthlyReturnMin: 3,
      monthlyReturnMax: 3,
      annualReturnRate: 36,
      description:
          'Mid-tier wealth plan for established portfolios. Invest ₹50,00,000 minimum and earn 3% monthly returns.',
      isFeatured: true,
    ),
    InvestmentPlanModel(
      id: 'PLAN003',
      name: 'BullWave Sovereign Crown',
      minimumInvestment: 10000000,
      monthlyReturnRate: 4,
      monthlyReturnMin: 4,
      monthlyReturnMax: 4,
      annualReturnRate: 48,
      description:
          'Flagship HNI plan for ultra-premium clients. Allocate ₹1 crore or more and unlock 4% monthly returns.',
      isFeatured: true,
    ),
  ];

  static InvestmentPlanModel? findById(String planId) {
    for (final plan in plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }
}
