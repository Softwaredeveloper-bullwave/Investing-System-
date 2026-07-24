import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/widgets/scale_tap.dart';
import 'home_theme_a.dart';

class PopularInvestmentItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  const PopularInvestmentItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });
}

/// 2x2 grid of investment product entry points — SIP, Options/F&O,
/// Commodities, Featured Plans — mirroring the "Popular Investments"
/// section of the mockup, wired to real routes in this app.
class HomePopularInvestments extends StatelessWidget {
  final List<PopularInvestmentItem> items;

  const HomePopularInvestments({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Popular Investments'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) => _PopularCard(item: items[index]),
        ),
      ],
    );
  }
}

class _PopularCard extends StatelessWidget {
  final PopularInvestmentItem item;

  const _PopularCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ScaleTap(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: p.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 18, color: item.tint),
            ),
            const Spacer(),
            Text(
              item.title,
              style: ThemeAType.cardTitle(size: 14, color: p.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              style: ThemeAType.muted(size: 11, color: p.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
