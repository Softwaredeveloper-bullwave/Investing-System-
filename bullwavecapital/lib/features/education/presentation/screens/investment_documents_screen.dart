import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/investment_doc_model.dart';
import '../provider/education_provider.dart';

class InvestmentDocumentsScreen extends StatefulWidget {
  const InvestmentDocumentsScreen({super.key});

  @override
  State<InvestmentDocumentsScreen> createState() => _InvestmentDocumentsScreenState();
}

class _InvestmentDocumentsScreenState extends State<InvestmentDocumentsScreen> {
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Research Vault'),
      body: Consumer<EducationProvider>(
        builder: (context, education, _) {
          if (education.isLoading && education.categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (education.error != null && education.categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(education.error!, textAlign: TextAlign.center, style: ThemeAType.body(color: p.textGrey)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: education.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = education.categories;
          final updatedLabel = education.updatedAt != null
              ? 'Updated ${_formatDate(education.updatedAt!)}'
              : null;

          return RefreshIndicator(
            onRefresh: education.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ThemeA.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: ThemeA.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Learn to invest', style: ThemeAType.cardTitle(color: p.textDark)),
                            const SizedBox(height: 4),
                            Text(
                              'Curated guides for Indian markets — start with Beginner, then explore topics at your pace.',
                              style: ThemeAType.body(color: p.textGrey, size: 13),
                            ),
                            if (updatedLabel != null) ...[
                              const SizedBox(height: 6),
                              Text(updatedLabel, style: ThemeAType.label(size: 11, color: p.textMuted)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Topics', style: ThemeAType.sectionTitle(color: p.textDark)),
                const SizedBox(height: 12),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryTile(category: category),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _CategoryTile extends StatelessWidget {
  final InvestmentDocCategory category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final countLabel = category.id == 'quizzes'
        ? '${category.quizzes.length} quiz${category.quizzes.length == 1 ? '' : 'zes'}'
        : '${category.articles.length} article${category.articles.length == 1 ? '' : 's'}';

    return GlassCard(
      onTap: () => context.push(AppRoutes.documentCategoryPath(category.id)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [category.accent, category.accent.withValues(alpha: 0.75)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.title, style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
                const SizedBox(height: 2),
                Text(
                  category.subtitle,
                  style: ThemeAType.body(color: p.textGrey, size: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(countLabel, style: ThemeAType.label(size: 11, color: p.textMuted)),
              Icon(Icons.chevron_right_rounded, color: p.textGrey, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}
