import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/investment_doc_model.dart';
import '../provider/education_provider.dart';

class DocumentCategoryScreen extends StatefulWidget {
  final String categoryId;

  const DocumentCategoryScreen({super.key, required this.categoryId});

  @override
  State<DocumentCategoryScreen> createState() => _DocumentCategoryScreenState();
}

class _DocumentCategoryScreenState extends State<DocumentCategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EducationProvider>().loadCatalog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final education = context.watch<EducationProvider>();
    final category = education.categoryById(widget.categoryId);

    if (education.isLoading && category == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Documents'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (category == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Documents'),
        body: const Center(child: Text('Category not found')),
      );
    }

    final isQuizCategory = category.id == 'quizzes';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: category.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(category.subtitle, style: ThemeAType.body(color: p.textGrey)),
          const SizedBox(height: 16),
          if (isQuizCategory)
            ...category.quizzes.map(
              (quiz) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuizListTile(quiz: quiz),
              ),
            )
          else
            ...category.articles.map(
              (article) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ArticleListTile(article: article),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArticleListTile extends StatelessWidget {
  final InvestmentDocArticle article;

  const _ArticleListTile({required this.article});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      onTap: () => context.push(
        AppRoutes.documentArticlePath(article.categoryId, article.id),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LevelChip(label: article.level),
              const Spacer(),
              Text(
                '${article.readMinutes} min read',
                style: ThemeAType.label(size: 11, color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(article.title, style: ThemeAType.cardTitle(color: p.textDark)),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: ThemeAType.body(color: p.textGrey, size: 14),
          ),
        ],
      ),
    );
  }
}

class _QuizListTile extends StatelessWidget {
  final InvestmentDocQuiz quiz;

  const _QuizListTile({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final questionCount = quiz.questions.length;
    return GlassCard(
      onTap: () => context.push(AppRoutes.documentQuizPath(quiz.id)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.quiz_outlined, color: Color(0xFF14B8A6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quiz.title, style: ThemeAType.cardTitle(color: p.textDark, size: 15)),
                const SizedBox(height: 4),
                Text(
                  questionCount > 0
                      ? '$questionCount questions · ${quiz.description}'
                      : quiz.description,
                  style: ThemeAType.body(color: p.textGrey, size: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.play_circle_outline_rounded, color: ThemeA.primary),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;

  const _LevelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeA.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: ThemeAType.label(size: 10, color: ThemeA.primary)),
    );
  }
}
