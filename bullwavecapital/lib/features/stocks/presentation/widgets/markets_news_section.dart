import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/news_image_url.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'markets_shared.dart';

class MarketNewsItem {
  final String headline;
  final String time;
  final String category;
  final String imageUrl;
  final String url;

  const MarketNewsItem({
    required this.headline,
    required this.time,
    required this.category,
    this.imageUrl = '',
    this.url = '',
  });

  factory MarketNewsItem.fromMap(Map<String, String> map) => MarketNewsItem(
        headline: _cleanHeadline(map['title'] ?? map['headline'] ?? ''),
        time: _shortTime(map),
        category: map['category']?.trim().isNotEmpty == true ? map['category']! : 'Markets',
        imageUrl: map['imageUrl']?.trim() ?? '',
        url: map['url']?.trim() ?? '',
      );

  static String _cleanHeadline(String raw) {
    if (raw.length <= 120) return raw.isEmpty ? 'Market update' : raw;
    return '${raw.substring(0, 117)}…';
  }

  static String _shortTime(Map<String, String> map) {
    final t = map['time']?.trim();
    if (t != null && t.isNotEmpty && t.length <= 20 && !t.startsWith('http')) return t;
    final sub = map['subtitle']?.trim();
    if (sub != null && sub.isNotEmpty && sub.length <= 24 && !sub.startsWith('http')) {
      return sub;
    }
    if (sub != null && sub.contains('•')) {
      return sub.split('•').first.trim();
    }
    return 'Recent';
  }
}

class MarketsNewsSection extends StatelessWidget {
  final List<Map<String, String>> news;

  const MarketsNewsSection({super.key, required this.news});

  static const _fallback = [
    MarketNewsItem(
      headline: 'NIFTY holds above 24,800 as IT and banking stocks lead gains',
      time: '12 min ago',
      category: 'Indices',
    ),
    MarketNewsItem(
      headline: 'RBI keeps repo rate unchanged; focus stays on inflation glide path',
      time: '45 min ago',
      category: 'Macro',
    ),
    MarketNewsItem(
      headline: 'FII inflows turn positive for third consecutive session',
      time: '1 hr ago',
      category: 'Flows',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = news.isNotEmpty
        ? news.take(4).map(MarketNewsItem.fromMap).toList()
        : _fallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketsSectionHeader(
          title: 'Market News',
          actionLabel: 'Read More',
          onAction: () => context.push(AppRoutes.stockNews),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _NewsCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final MarketNewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final displayImageUrl = resolveNewsImageUrl(item.imageUrl);
    final hasImage = displayImageUrl.isNotEmpty;

    return ScaleTap(
      onTap: () => context.push(AppRoutes.stockNews),
      child: SizedBox(
        width: 260,
        child: GlassCard(
          radius: 20,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 84,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        CachedNetworkImage(
                          imageUrl: displayImageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 220),
                          placeholder: (_, _) => _NewsImagePlaceholder(p: p),
                          errorWidget: (_, _, _) => _NewsImagePlaceholder(p: p),
                        )
                      else
                        _NewsImagePlaceholder(p: p),
                      Positioned(
                        left: 14,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.category,
                            style: ThemeAType.label(size: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.headline,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: ThemeAType.cardTitle(color: p.textDark, size: 14),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: p.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ThemeAType.label(size: 11, color: p.textMuted),
                            ),
                          ),
                          Text('More', style: ThemeAType.action(size: 12, color: p.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  final ThemePalette p;

  const _NewsImagePlaceholder({required this.p});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.primary.withValues(alpha: 0.35), p.card],
        ),
      ),
      child: Center(
        child: Icon(Icons.newspaper_rounded, color: p.primary.withValues(alpha: 0.7), size: 28),
      ),
    );
  }
}
