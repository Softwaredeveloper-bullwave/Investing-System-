import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/modern_icon_badge.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'markets_shared.dart';

class MarketsLearningHub extends StatelessWidget {
  const MarketsLearningHub({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = [
      _LearningItem(
        label: 'Investment Journal',
        subtitle: 'Track ideas & trades',
        icon: Icons.edit_note_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        onTap: () => context.push(AppRoutes.investmentNotes),
      ),
      _LearningItem(
        label: 'Research Vault',
        subtitle: 'Guides, docs & quizzes',
        icon: Icons.folder_special_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        onTap: () => context.push(AppRoutes.investmentDocuments),
      ),
      _LearningItem(
        label: 'Academy',
        subtitle: 'Structured learning paths',
        icon: Icons.school_rounded,
        gradient: const [Color(0xFF3B82F6), Color(0xFF22D3EE)],
        onTap: () => context.push(AppRoutes.documentCategoryPath('beginner')),
      ),
      _LearningItem(
        label: 'Calculator',
        subtitle: 'SIP & returns planner',
        icon: Icons.calculate_rounded,
        gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
        onTap: () => context.push(AppRoutes.investmentCalculator),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MarketsSectionHeader(
          title: 'Learning',
          subtitle: 'Build conviction with tools & research',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ScaleTap(
                    onTap: item.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: p.surface.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.borderLight),
                      ),
                      child: Row(
                        children: [
                          ModernIconBadge(
                            icon: item.icon,
                            gradient: item.gradient,
                            size: 44,
                            style: IconBadgeStyle.premiumCircle,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.label, style: ThemeAType.cardTitle(color: p.textDark, size: 15)),
                                Text(item.subtitle, style: ThemeAType.body(color: p.textGrey, size: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: p.textMuted),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LearningItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _LearningItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}
