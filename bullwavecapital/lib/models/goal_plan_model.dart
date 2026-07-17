import 'package:flutter/material.dart';

class GoalReturnTierModel {
  final String id;
  final String name;
  final String tagline;
  final double minMonthly;
  final double? maxMonthly;
  final double annualReturnRate;
  final String badge;
  final Color color;

  const GoalReturnTierModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.minMonthly,
    this.maxMonthly,
    required this.annualReturnRate,
    required this.badge,
    required this.color,
  });

  String get rangeLabel {
    if (maxMonthly == null) return '₹1,00,000+ / month';
    if (minMonthly <= 500 && maxMonthly! <= 9999) return '₹500 – ₹10,000 / month';
    if (minMonthly >= 10000 && maxMonthly! <= 99999) return '₹10,000 – ₹1,00,000 / month';
    return '₹${minMonthly.toStringAsFixed(0)} – ₹${maxMonthly!.toStringAsFixed(0)} / month';
  }
}

class GoalTemplateModel {
  final String id;
  final String category;
  final String name;
  final String tagline;
  final String icon;
  final Color color;
  final double minTarget;
  final double suggestedMonthly;
  final int minDurationMonths;
  final int maxDurationMonths;

  const GoalTemplateModel({
    required this.id,
    required this.category,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.minTarget,
    required this.suggestedMonthly,
    this.minDurationMonths = 3,
    this.maxDurationMonths = 24,
  });

  IconData get iconData {
    switch (icon) {
      case 'home':
        return Icons.home_rounded;
      case 'elderly':
        return Icons.elderly_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      default:
        return Icons.savings_rounded;
    }
  }
}

class UserGoalPlanModel {
  final String id;
  final String category;
  final String title;
  final double targetAmount;
  final double monthlyContribution;
  final int durationMonths;
  final double accumulatedAmount;
  final double returnsEarned;
  final double annualReturnRate;
  final double projectedMaturityValue;
  final double projectedReturns;
  final int installmentsDone;
  final int totalInstallments;
  final double progressPercent;
  final String? nextContributionDate;
  final String? targetDate;
  final String status;
  final String referenceId;
  final String returnTier;
  final Color color;
  final bool canWithdraw;
  final bool isDue;

  const UserGoalPlanModel({
    required this.id,
    required this.category,
    required this.title,
    required this.targetAmount,
    required this.monthlyContribution,
    required this.durationMonths,
    required this.accumulatedAmount,
    this.returnsEarned = 0,
    this.annualReturnRate = 8,
    this.projectedMaturityValue = 0,
    this.projectedReturns = 0,
    required this.installmentsDone,
    required this.totalInstallments,
    required this.progressPercent,
    this.nextContributionDate,
    this.targetDate,
    required this.status,
    required this.referenceId,
    this.returnTier = 'starter',
    required this.color,
    this.canWithdraw = false,
    this.isDue = false,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
}

class GoalRemindersModel {
  final List<UserGoalPlanModel> due;
  final int activeCount;

  const GoalRemindersModel({required this.due, required this.activeCount});
}

/// Default return tiers when API does not supply them.
class GoalReturnTiersDefaults {
  GoalReturnTiersDefaults._();

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
}
