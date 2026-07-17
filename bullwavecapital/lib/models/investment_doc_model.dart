import 'package:flutter/material.dart';

class InvestmentDocCategory {
  final String id;
  final String title;
  final String subtitle;
  final String iconName;
  final String accentHex;
  final List<InvestmentDocArticle> articles;
  final List<InvestmentDocQuiz> quizzes;

  const InvestmentDocCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.accentHex,
    this.articles = const [],
    this.quizzes = const [],
  });

  IconData get icon => _iconFromName(iconName);
  Color get accent => _colorFromHex(accentHex);

  int get itemCount => articles.length + quizzes.length;

  factory InvestmentDocCategory.fromJson(Map<String, dynamic> json) {
    final articlesJson = json['articles'] as List<dynamic>? ?? [];
    final quizzesJson = json['quizzes'] as List<dynamic>? ?? [];
    return InvestmentDocCategory(
      id: json['slug'] as String? ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'menu_book',
      accentHex: json['accentHex'] as String? ?? '#3B82F6',
      articles: articlesJson
          .map((e) => InvestmentDocArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
      quizzes: quizzesJson
          .map((e) => InvestmentDocQuiz.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InvestmentDocArticle {
  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final List<String> sections;
  final int readMinutes;
  final String level;

  const InvestmentDocArticle({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.sections,
    this.readMinutes = 4,
    this.level = 'Beginner',
  });

  String get preview {
    final text = sections.isNotEmpty ? sections.first : summary;
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  factory InvestmentDocArticle.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'] as List<dynamic>? ?? [];
    return InvestmentDocArticle(
      id: json['slug'] as String? ?? json['id']?.toString() ?? '',
      categoryId: json['categorySlug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sections: sectionsRaw.map((e) => e.toString()).toList(),
      readMinutes: _int(json['readMinutes'], fallback: 4),
      level: json['level'] as String? ?? 'Beginner',
    );
  }
}

class InvestmentDocQuiz {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final List<InvestmentQuizQuestion> questions;

  const InvestmentDocQuiz({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.questions,
  });

  factory InvestmentDocQuiz.fromJson(Map<String, dynamic> json) {
    final questionsJson = json['questions'] as List<dynamic>? ?? [];
    return InvestmentDocQuiz(
      id: json['slug'] as String? ?? json['id']?.toString() ?? '',
      categoryId: json['categorySlug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      questions: questionsJson
          .map((e) => InvestmentQuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InvestmentQuizQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const InvestmentQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory InvestmentQuizQuestion.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'] as List<dynamic>? ?? [];
    return InvestmentQuizQuestion(
      prompt: (json['prompt'] as String? ?? '').trim(),
      options: optionsRaw.map((e) => e.toString()).toList(),
      correctIndex: _int(json['correctIndex']),
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

IconData _iconFromName(String name) {
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

Color _colorFromHex(String hex) {
  var cleaned = hex.replaceAll('#', '');
  if (cleaned.length == 6) cleaned = 'FF$cleaned';
  try {
    return Color(int.parse(cleaned, radix: 16));
  } catch (_) {
    return const Color(0xFF3B82F6);
  }
}

class EducationCatalogModel {
  final DateTime? updatedAt;
  final List<InvestmentDocCategory> categories;

  const EducationCatalogModel({required this.updatedAt, required this.categories});
}
