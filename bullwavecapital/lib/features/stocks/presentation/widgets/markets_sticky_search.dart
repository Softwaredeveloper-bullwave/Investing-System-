import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';

class MarketsStickySearchDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onVoiceTap;

  MarketsStickySearchDelegate({
    required this.controller,
    required this.onChanged,
    this.onVoiceTap,
  });

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final p = context.palette;
    return Container(
      color: p.bg.withValues(alpha: overlapsContent ? 0.96 : 0.88),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: p.card.withValues(alpha: p.isDark ? 0.7 : 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.borderLight),
          boxShadow: [
            if (overlapsContent)
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: p.textMuted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: ThemeAType.body(color: p.textDark, size: 15),
                decoration: InputDecoration(
                  hintText: 'Search Stocks, ETF, Mutual Funds, IPOs...',
                  hintStyle: ThemeAType.body(color: p.textMuted, size: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            IconButton(
              onPressed: onVoiceTap,
              icon: Icon(Icons.mic_rounded, color: p.primary, size: 22),
              tooltip: 'Voice search',
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant MarketsStickySearchDelegate oldDelegate) =>
      oldDelegate.controller != controller;
}
