import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../data/economic_calendar_mock_data.dart';
import 'markets_shared.dart';

/// Horizontal preview strip on Markets — tap opens full calendar.
class MarketsEconomicCalendarStrip extends StatelessWidget {
  final VoidCallback onOpenFull;

  const MarketsEconomicCalendarStrip({super.key, required this.onOpenFull});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final events = EconomicCalendarMockData.events;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketsSectionHeader(
          title: 'Economic Calendar',
          subtitle: 'RBI · Inflation · GDP · Earnings',
          actionLabel: 'See all',
          onAction: onOpenFull,
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _HorizontalEventCard(
                event: events[index],
                onTap: onOpenFull,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: ScaleTap(
            onTap: onOpenFull,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.primary.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: p.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Open full economic calendar',
                    style: ThemeAType.label(size: 13, color: p.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HorizontalEventCard extends StatelessWidget {
  final EconomicCalendarEvent event;
  final VoidCallback onTap;

  const _HorizontalEventCard({required this.event, required this.onTap});

  Color _impactColor(ThemePalette p) {
    if (event.impact >= 3) return p.negative;
    if (event.impact == 2) return const Color(0xFFF59E0B);
    return p.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final impact = _impactColor(p);

    return ScaleTap(
      onTap: onTap,
      child: SizedBox(
        width: 236,
        child: GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: impact.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.countryCode,
                      style: ThemeAType.label(size: 10, color: impact)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: impact.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.displayImpactLabel,
                      style: ThemeAType.label(size: 10, color: impact)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Text(event.dateLabel, style: ThemeAType.label(size: 11, color: p.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThemeAType.cardTitle(color: p.textDark, size: 14),
              ),
              const SizedBox(height: 4),
              Text(
                event.marketImpact.isNotEmpty
                    ? event.marketImpact
                    : '${event.time} · ${event.category}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThemeAType.body(color: p.textGrey, size: 11),
              ),
              const Spacer(),
              Row(
                children: [
                  _MiniStat(label: 'Prev', value: event.previous ?? '—', p: p),
                  const SizedBox(width: 6),
                  _MiniStat(label: 'Fcst', value: event.forecast ?? '—', p: p),
                  const Spacer(),
                  Text(event.category, style: ThemeAType.label(size: 10, color: p.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette p;

  const _MiniStat({required this.label, required this.value, required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ThemeAType.label(size: 9, color: p.textMuted)),
        Text(value, style: ThemeAType.label(size: 11, color: p.textDark)),
      ],
    );
  }
}

/// Full economic calendar screen.
class EconomicCalendarScreen extends StatefulWidget {
  const EconomicCalendarScreen({super.key});

  @override
  State<EconomicCalendarScreen> createState() => _EconomicCalendarScreenState();
}

class _EconomicCalendarScreenState extends State<EconomicCalendarScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final events = EconomicCalendarMockData.byCategory(_filter);
    final grouped = <String, List<EconomicCalendarEvent>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.dateLabel, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Economic Calendar'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RBI, inflation, GDP & earnings',
                  style: ThemeAType.cardTitle(color: p.textDark, size: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track policy decisions, CPI/WPI, growth prints, and corporate earnings with market impact.',
                  style: ThemeAType.body(color: p.textGrey, size: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _LegendDot(color: p.negative, label: 'High impact'),
                    const SizedBox(width: 12),
                    _LegendDot(color: const Color(0xFFF59E0B), label: 'Medium'),
                    const SizedBox(width: 12),
                    _LegendDot(color: p.textMuted, label: 'Low'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: EconomicCalendarMockData.filterCategories.map((cat) {
                final selected = _filter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No events in this filter.',
                  style: ThemeAType.body(color: p.textMuted, size: 14),
                ),
              ),
            )
          else
            ...grouped.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: ThemeAType.label(size: 13, color: p.primary)),
                    const SizedBox(height: 10),
                    ...entry.value.map((e) => _FullEventTile(event: e)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: ThemeAType.label(size: 11, color: p.textMuted)),
      ],
    );
  }
}

class _FullEventTile extends StatelessWidget {
  final EconomicCalendarEvent event;

  const _FullEventTile({required this.event});

  Color _impactColor(ThemePalette p) {
    if (event.impact >= 3) return p.negative;
    if (event.impact == 2) return const Color(0xFFF59E0B);
    return p.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final impact = _impactColor(p);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: impact.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: impact.withValues(alpha: 0.3)),
              ),
              child: Text(
                event.countryCode,
                style: ThemeAType.label(size: 11, color: impact).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: ThemeAType.cardTitle(color: p.textDark, size: 15),
                        ),
                      ),
                      Text(event.time, style: ThemeAType.label(size: 11, color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.country} · ${event.category} · ${event.displayImpactLabel} impact',
                    style: ThemeAType.body(color: p.textGrey, size: 12),
                  ),
                  if (event.marketImpact.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.marketImpact,
                      style: ThemeAType.body(color: p.textDark, size: 12),
                    ),
                  ],
                  if (event.relatedSymbols.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: event.relatedSymbols
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(s, style: ThemeAType.label(size: 10, color: p.primary)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _FullStat(label: 'Previous', value: event.previous ?? '—', p: p),
                      const SizedBox(width: 8),
                      _FullStat(label: 'Forecast', value: event.forecast ?? '—', p: p),
                      const SizedBox(width: 8),
                      _FullStat(
                        label: 'Actual',
                        value: event.actual ?? 'Pending',
                        p: p,
                        highlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullStat extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette p;
  final bool highlight;

  const _FullStat({
    required this.label,
    required this.value,
    required this.p,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ThemeAType.label(size: 9, color: p.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ThemeAType.label(
                size: 12,
                color: highlight ? p.primary : p.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
