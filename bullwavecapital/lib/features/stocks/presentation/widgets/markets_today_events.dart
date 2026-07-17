import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import 'markets_shared.dart';

class MarketEventItem {
  final String title;
  final String type;
  final String time;
  final IconData icon;
  final Color accent;

  const MarketEventItem({
    required this.title,
    required this.type,
    required this.time,
    required this.icon,
    required this.accent,
  });
}

class MarketsTodayEvents extends StatelessWidget {
  const MarketsTodayEvents({super.key});

  static const _events = [
    MarketEventItem(
      title: 'Zomato Q4 Results',
      type: 'Results',
      time: '4:00 PM',
      icon: Icons.analytics_outlined,
      accent: Color(0xFF3B82F6),
    ),
    MarketEventItem(
      title: 'Hyundai Motor India IPO',
      type: 'IPO',
      time: 'Open',
      icon: Icons.apartment_outlined,
      accent: Color(0xFF0EA5E9),
    ),
    MarketEventItem(
      title: 'ITC Interim Dividend',
      type: 'Dividend',
      time: 'Ex-date',
      icon: Icons.payments_outlined,
      accent: Color(0xFF10B981),
    ),
    MarketEventItem(
      title: 'Reliance 1:1 Bonus',
      type: 'Bonus',
      time: 'Record date',
      icon: Icons.card_giftcard_outlined,
      accent: Color(0xFF8B5CF6),
    ),
    MarketEventItem(
      title: 'TCS Stock Split 1:5',
      type: 'Split',
      time: 'Tomorrow',
      icon: Icons.call_split_rounded,
      accent: Color(0xFFF59E0B),
    ),
    MarketEventItem(
      title: 'RBI MPC Minutes',
      type: 'RBI',
      time: '2:30 PM',
      icon: Icons.account_balance_outlined,
      accent: Color(0xFFEF4444),
    ),
    MarketEventItem(
      title: 'US Fed Meeting',
      type: 'Fed Meeting',
      time: '11:30 PM IST',
      icon: Icons.public_outlined,
      accent: Color(0xFF6366F1),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MarketsSectionHeader(
          title: "Today's Events",
          subtitle: 'Upcoming market calendar',
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _events.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _EventCard(item: _events[index]),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final MarketEventItem item;

  const _EventCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 168,
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: item.accent),
                ),
                const Spacer(),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.label(size: 9, color: p.textMuted),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThemeAType.cardTitle(color: p.textDark, size: 13),
            ),
            const SizedBox(height: 4),
            Text(item.time, style: ThemeAType.label(size: 11, color: p.textMuted)),
          ],
        ),
      ),
    );
  }
}
