import 'package:flutter/material.dart';

import '../../../models/goal_plan_model.dart';

/// Offline fallback when API templates are unavailable.
class GoalTemplatesCatalog {
  GoalTemplatesCatalog._();

  static const templates = [
    GoalTemplateModel(
      id: 'GOAL_HOUSE',
      category: 'house',
      name: 'Dream Home',
      tagline: 'Save for down payment or renovation',
      icon: 'home',
      color: Color(0xFF9333EA),
      minTarget: 50000,
      suggestedMonthly: 5000,
    ),
    GoalTemplateModel(
      id: 'GOAL_RETIREMENT',
      category: 'retirement',
      name: 'Retirement',
      tagline: 'Build your retirement corpus',
      icon: 'elderly',
      color: Color(0xFF6366F1),
      minTarget: 25000,
      suggestedMonthly: 3000,
    ),
    GoalTemplateModel(
      id: 'GOAL_EDUCATION',
      category: 'education',
      name: 'Education',
      tagline: 'Fund school or college fees',
      icon: 'school',
      color: Color(0xFF10B981),
      minTarget: 20000,
      suggestedMonthly: 2500,
    ),
    GoalTemplateModel(
      id: 'GOAL_MARRIAGE',
      category: 'marriage',
      name: 'Marriage',
      tagline: 'Plan wedding expenses stress-free',
      icon: 'favorite',
      color: Color(0xFFEC4899),
      minTarget: 50000,
      suggestedMonthly: 6000,
    ),
    GoalTemplateModel(
      id: 'GOAL_VEHICLE',
      category: 'vehicle',
      name: 'Vehicle',
      tagline: 'Save for bike or car down payment',
      icon: 'directions_car',
      color: Color(0xFFF59E0B),
      minTarget: 30000,
      suggestedMonthly: 4000,
    ),
  ];

  static GoalTemplateModel? byCategory(String category) {
    try {
      return templates.firstWhere((t) => t.category == category);
    } catch (_) {
      return null;
    }
  }
}
