import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/paper_competition_model.dart';
import '../provider/paper_competition_provider.dart';

class PaperRiskMeterCard extends StatelessWidget {
  final PaperRiskMeterModel? meter;
  final bool isLoading;
  final String title;
  final EdgeInsetsGeometry padding;

  const PaperRiskMeterCard({
    super.key,
    required this.meter,
    this.isLoading = false,
    this.title = 'Risk Meter',
    this.padding = EdgeInsets.zero,
  });

  /// Live Markets / portfolio risk meter.
  const PaperRiskMeterCard.market({
    super.key,
    required this.meter,
    this.isLoading = false,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 0),
  }) : title = 'Market Risk Meter';

  Color _colorFor(ThemePalette p, int score) {
    if (score >= 80) return p.negative;
    if (score >= 60) return const Color(0xFFF97316);
    if (score >= 35) return const Color(0xFFF59E0B);
    return p.positive;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (isLoading && meter == null) {
      return Padding(
        padding: padding,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final m = meter;
    if (m == null) return const SizedBox.shrink();
    final color = _colorFor(p, m.score);

    return Padding(
      padding: padding,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        glow: true,
        glowColor: color.withValues(alpha: 0.16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: ThemeAType.cardTitle(color: p.textDark, size: 16)),
                ),
                Text('${m.score}', style: ThemeAType.sectionTitle(color: color, size: 22)),
              ],
            ),
            const SizedBox(height: 6),
            Text(m.label, style: ThemeAType.label(size: 12, color: color)),
            const SizedBox(height: 12),
            _RiskGauge(score: m.score, color: color),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low', style: ThemeAType.label(size: 10, color: p.positive)),
                Text('Medium', style: ThemeAType.label(size: 10, color: const Color(0xFFF59E0B))),
                Text('High', style: ThemeAType.label(size: 10, color: const Color(0xFFF97316))),
                Text('Extreme', style: ThemeAType.label(size: 10, color: p.negative)),
              ],
            ),
            const SizedBox(height: 10),
            Text(m.summary, style: ThemeAType.body(color: p.textGrey, size: 12)),
            if (m.factors.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...m.factors.take(3).map((f) {
                final fc = f.isPositive ? p.positive : p.negative;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        f.isPositive ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        size: 14,
                        color: fc,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${f.label}: ${f.detail}',
                          style: ThemeAType.body(color: p.textGrey, size: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiskGauge extends StatelessWidget {
  final int score;
  final Color color;

  const _RiskGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final marker = (score.clamp(0, 100) / 100) * width;
        return SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF22C55E),
                      Color(0xFFF59E0B),
                      Color(0xFFF97316),
                      Color(0xFFEF4444),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: marker - 7,
                top: 0,
                child: Container(
                  width: 14,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PaperCompetitionCard extends StatelessWidget {
  final List<PaperCompetitionModel> competitions;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final void Function(PaperCompetitionModel) onOpen;

  const PaperCompetitionCard({
    super.key,
    required this.competitions,
    required this.isLoading,
    required this.onCreate,
    required this.onJoin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = competitions.isNotEmpty ? competitions.first : null;

    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: p.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compete with friends',
                  style: ThemeAType.cardTitle(color: p.textDark, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Create a paper arena, share the invite code, and race on virtual P&L.',
            style: ThemeAType.body(color: p.textGrey, size: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: isLoading ? null : onCreate,
                  child: const Text('Create'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onJoin,
                  child: const Text('Join code'),
                ),
              ),
            ],
          ),
          if (top != null) ...[
            const SizedBox(height: 14),
            ScaleTap(
              onTap: () => onOpen(top),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            top.name,
                            style: ThemeAType.label(size: 13, color: p.textDark)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          top.status.toUpperCase(),
                          style: ThemeAType.label(size: 10, color: p.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code ${top.inviteCode} · ${top.membersCount} friends'
                      '${top.you != null ? ' · Your rank #${top.you!.rank}' : ''}',
                      style: ThemeAType.body(color: p.textMuted, size: 12),
                    ),
                    if (top.standings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...top.standings.take(3).map((s) {
                        final pct = s.pnlPercent;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Text('#${s.rank}', style: ThemeAType.label(size: 11, color: p.textMuted)),
                              ),
                              Expanded(
                                child: Text(
                                  s.isYou ? '${s.displayName} (you)' : s.displayName,
                                  style: ThemeAType.body(color: p.textDark, size: 12),
                                ),
                              ),
                              Text(
                                '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                                style: ThemeAType.label(
                                  size: 12,
                                  color: pct >= 0 ? p.positive : p.negative,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showCreateCompetitionSheet(BuildContext context) async {
  if (!await ensureBankVerified(context)) return;
  if (!context.mounted) return;

  final p = context.palette;
  final nameController = TextEditingController();
  final balanceController = TextEditingController(text: '1000000');
  var days = 7;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.borderLight),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create competition', style: ThemeAType.sectionTitle(color: p.textDark)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Arena name',
                      hintText: 'Weekend Warriors',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Starting capital (₹)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Duration', style: ThemeAType.label(size: 12, color: p.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [3, 7, 14].map((d) {
                      final selected = days == d;
                      return ChoiceChip(
                        label: Text('$d days'),
                        selected: selected,
                        onSelected: (_) => setModal(() => days = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Create & get invite code'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (ok != true || !context.mounted) return;
  final provider = context.read<PaperCompetitionProvider>();
  final err = await provider.createCompetition(
    name: nameController.text.trim(),
    startingBalance: double.tryParse(balanceController.text.trim()) ?? 1000000,
    durationDays: days,
  );
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  final created = provider.selected;
  if (created != null) {
    await Clipboard.setData(ClipboardData(text: created.inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite code ${created.inviteCode} copied')),
    );
    try {
      await SharePlus.instance.share(ShareParams(text: created.shareMessage));
    } catch (_) {}
  }
}

Future<void> showJoinCompetitionSheet(BuildContext context) async {
  if (!await ensureBankVerified(context)) return;
  if (!context.mounted) return;

  final p = context.palette;
  final codeController = TextEditingController();

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join with invite code', style: ThemeAType.sectionTitle(color: p.textDark)),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'ABC123',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Join competition'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (ok != true || !context.mounted) return;
  final err = await context.read<PaperCompetitionProvider>().joinCompetition(
        codeController.text.trim(),
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(err ?? 'Joined competition')),
  );
}

Future<void> showCompetitionDetailSheet(
  BuildContext context,
  PaperCompetitionModel competition,
) async {
  final p = context.palette;
  await context.read<PaperCompetitionProvider>().loadCompetition(competition.id);
  if (!context.mounted) return;
  final live = context.read<PaperCompetitionProvider>().selected ?? competition;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(live.name, style: ThemeAType.sectionTitle(color: p.textDark)),
            const SizedBox(height: 4),
            Text(
              'Code ${live.inviteCode} · ${live.status.toUpperCase()} · ends ${DateFormatter.display(live.endsAt)}',
              style: ThemeAType.body(color: p.textMuted, size: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: live.inviteCode));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Copied ${live.inviteCode}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy code'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: live.shareMessage)),
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Leaderboard', style: ThemeAType.cardTitle(color: p.textDark, size: 15)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: live.standings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = live.standings[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: s.isYou
                          ? p.primary.withValues(alpha: 0.1)
                          : p.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: s.isYou ? p.primary.withValues(alpha: 0.35) : p.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: p.primary.withValues(alpha: 0.15),
                          child: Text(
                            '#${s.rank}',
                            style: ThemeAType.label(size: 11, color: p.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.isYou ? '${s.displayName} (you)' : s.displayName,
                                style: ThemeAType.body(color: p.textDark, size: 13)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${s.tradesCount} trades · ${CurrencyFormatter.format(s.equity)}',
                                style: ThemeAType.label(size: 11, color: p.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${s.pnlPercent >= 0 ? '+' : ''}${s.pnlPercent.toStringAsFixed(1)}%',
                          style: ThemeAType.label(
                            size: 13,
                            color: s.pnlPercent >= 0 ? p.positive : p.negative,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
