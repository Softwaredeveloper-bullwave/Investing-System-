import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/investment_doc_model.dart';

class EducationProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<InvestmentDocCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _updatedAt;

  List<InvestmentDocCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get updatedAt => _updatedAt;

  Future<void> loadCatalog({bool force = false}) async {
    if (_categories.isNotEmpty && !force) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final catalog = await _api.getEducationCatalog();
      _categories = catalog.categories;
      _updatedAt = catalog.updatedAt;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      _categories = [];
    } catch (_) {
      _error = 'Could not load documents. Is Django running?';
      _categories = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadCatalog(force: true);

  InvestmentDocCategory? categoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  InvestmentDocArticle? articleById(String categoryId, String articleId) {
    final cat = categoryById(categoryId);
    if (cat == null) return null;
    try {
      return cat.articles.firstWhere((a) => a.id == articleId);
    } catch (_) {
      return null;
    }
  }

  InvestmentDocQuiz? quizById(String quizId) {
    for (final cat in _categories) {
      for (final quiz in cat.quizzes) {
        if (quiz.id == quizId) return quiz;
      }
    }
    return null;
  }

  Future<InvestmentDocQuiz?> fetchQuiz(String quizSlug) async {
    final cached = quizById(quizSlug);
    if (cached != null && cached.questions.isNotEmpty) return cached;

    try {
      final quiz = await _api.getEducationQuiz(quizSlug);
      _mergeQuiz(quiz);
      notifyListeners();
      return quiz;
    } catch (_) {
      return cached;
    }
  }

  void _mergeQuiz(InvestmentDocQuiz quiz) {
    for (var i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final idx = cat.quizzes.indexWhere((q) => q.id == quiz.id);
      if (idx >= 0) {
        final quizzes = [...cat.quizzes];
        quizzes[idx] = quiz;
        _categories[i] = InvestmentDocCategory(
          id: cat.id,
          title: cat.title,
          subtitle: cat.subtitle,
          iconName: cat.iconName,
          accentHex: cat.accentHex,
          articles: cat.articles,
          quizzes: quizzes,
        );
        return;
      }
    }
  }
}
