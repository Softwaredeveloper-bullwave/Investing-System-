import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/goal_plan_model.dart';

class GoalReturnTiersCatalog {
  GoalReturnTiersCatalog._();

  static const tiers = [
    GoalReturnTierModel(
      id: 'starter',
      name: 'Starter',
      tagline: 'Perfect to begin saving',
      minMonthly: 500,
      maxMonthly: 9999,
      annualReturnRate: 8,
      badge: 'Up to 8% p.a.',
      color: Color(0xFF10B981),
    ),
    GoalReturnTierModel(
      id: 'growth',
      name: 'Growth',
      tagline: 'Higher SIP, higher returns',
      minMonthly: 10000,
      maxMonthly: 99999,
      annualReturnRate: 12,
      badge: 'Up to 12% p.a.',
      color: Color(0xFF6366F1),
    ),
    GoalReturnTierModel(
      id: 'elite',
      name: 'Elite',
      tagline: 'Premium wealth builder',
      minMonthly: 100000,
      maxMonthly: null,
      annualReturnRate: 16,
      badge: 'Up to 16% p.a.',
      color: Color(0xFFF59E0B),
    ),
  ];

  static GoalReturnTierModel tierForMonthly(double amount) {
    GoalReturnTierModel selected = tiers.first;
    for (final tier in tiers) {
      final inRange = amount >= tier.minMonthly &&
          (tier.maxMonthly == null || amount <= tier.maxMonthly!);
      if (inRange) selected = tier;
    }
    return selected;
  }

  static double annualRateForMonthly(double amount) =>
      tierForMonthly(amount).annualReturnRate;

  static ({double maturity, double invested, double returns}) projectedMaturity({
    required double monthlyContribution,
    required int months,
    required double annualReturnRate,
  }) {
    if (months <= 0 || monthlyContribution <= 0) {
      return (maturity: 0, invested: 0, returns: 0);
    }
    final invested = monthlyContribution * months;
    final r = annualReturnRate / 100 / 12;
    if (r == 0) return (maturity: invested, invested: invested, returns: 0);
    final fv = monthlyContribution * ((math.pow(1 + r, months) - 1) / r);
    return (maturity: fv, invested: invested, returns: fv - invested);
  }
}
