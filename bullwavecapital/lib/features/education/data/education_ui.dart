import 'package:flutter/material.dart';

class EducationUi {
  EducationUi._();

  static IconData iconFromName(String name) {
    switch (name) {
      case 'school':
        return Icons.school_rounded;
      case 'show_chart':
        return Icons.show_chart_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'call_made':
        return Icons.call_made_rounded;
      case 'timeline':
        return Icons.timeline_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'pie_chart':
        return Icons.pie_chart_rounded;
      case 'apartment':
        return Icons.apartment_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  static Color colorFromHex(String hex) {
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    try {
      return Color(int.parse(cleaned, radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }
}

/// Starter note templates for beginners.
class BeginnerNoteTemplates {
  BeginnerNoteTemplates._();

  static const templates = [
    (
      title: 'My first investment plan',
      body: 'Goal:\nHorizon (years):\nMonthly amount:\nRisk level (low/medium/high):\nStocks/funds shortlisted:\nWhy I chose them:\n',
    ),
    (
      title: 'Stock research — SYMBOL',
      body: 'Company business:\nRevenue trend:\nKey risks:\nPE vs sector:\nMy entry price:\nTarget:\nStop / exit if wrong:\n',
    ),
    (
      title: 'Weekly market journal',
      body: 'Week of:\nNIFTY bias:\nWhat I learned:\nMistakes to avoid:\nPlan for next week:\n',
    ),
  ];
}
