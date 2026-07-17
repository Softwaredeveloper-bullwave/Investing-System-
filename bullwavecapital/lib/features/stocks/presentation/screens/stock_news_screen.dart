import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/news_image_url.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_features_provider.dart';

class StockNewsScreen extends StatefulWidget {
  const StockNewsScreen({super.key});

  @override
  State<StockNewsScreen> createState() => _StockNewsScreenState();
}

class _StockNewsScreenState extends State<StockNewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final features = context.read<StockFeaturesProvider>();
      if (features.news.isEmpty) {
        features.refreshNews();
      }
    });
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Market News'),
      body: Consumer<StockFeaturesProvider>(
        builder: (context, features, _) {
          if (features.isNewsLoading && features.news.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary));
          }
          if (features.news.isEmpty) {
            return RefreshIndicator(
              color: AppColors.brandPrimary,
              onRefresh: features.refreshNews,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No news available. Pull to refresh.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.brandPrimary,
            onRefresh: features.refreshNews,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: features.news.length + (features.isUsingDemoNews ? 1 : 0),
              itemBuilder: (_, i) {
                if (features.isUsingDemoNews && i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: PremiumAlertBanner(
                      message:
                          'Sample headlines shown offline. Start Django for live RSS + Finnhub news.',
                      type: PremiumAlertType.info,
                    ),
                  );
                }
                final index = features.isUsingDemoNews ? i - 1 : i;
                final article = features.news[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _NewsArticleCard(
                    article: article,
                    onTap: () async {
                      if (article.url.isNotEmpty) {
                        await _openArticle(article.url);
                        return;
                      }
                      if (article.relatedSymbols.isNotEmpty && context.mounted) {
                        context.push('${AppRoutes.stockDetail}?symbol=${article.relatedSymbols.first}');
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NewsArticleCard extends StatelessWidget {
  final StockNewsModel article;
  final VoidCallback onTap;

  const _NewsArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayImageUrl = resolveNewsImageUrl(article.imageUrl);
    final hasImage = displayImageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: displayImageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, _) => Container(
                      height: 180,
                      color: colors.surfaceSecondary,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => _NewsImageFallback(category: article.category),
                  ),
                )
              else
                _NewsImageFallback(category: article.category, compact: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryChip(label: article.category),
                        if (article.relatedSymbols.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              article.relatedSymbols.take(3).join(', '),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: colors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.35,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${article.source} • ${DateFormatter.display(article.publishedAt)}',
                            style: GoogleFonts.inter(fontSize: 11, color: colors.textMuted),
                          ),
                        ),
                        if (article.url.isNotEmpty)
                          const Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.brandPrimary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.brandPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _NewsImageFallback extends StatelessWidget {
  final String category;
  final bool compact;

  const _NewsImageFallback({required this.category, this.compact = false});

  Color get _accent {
    switch (category.toLowerCase()) {
      case 'earnings':
        return AppColors.brandGold;
      case 'economy':
        return AppColors.secondary;
      case 'ipo':
        return AppColors.brandPink;
      case 'indices':
        return AppColors.brandCyan;
      default:
        return AppColors.brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = compact ? 72.0 : 180.0;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.28),
            AppColors.surfaceSecondary,
          ],
        ),
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          size: compact ? 28 : 48,
          color: _accent.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
