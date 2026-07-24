import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/goal_plan_model.dart';
import '../../../home/presentation/widgets/home_theme_a.dart';

class HomeGoalsSection extends StatelessWidget {
  final List<UserGoalPlanModel> goals;
  final VoidCallback? onViewAll;

  const HomeGoalsSection({super.key, required this.goals, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'My Goals',
          actionLabel: 'View All',
          onAction: onViewAll ?? () => context.push(AppRoutes.goalPlans),
          reserveFabSpace: true,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final g = goals[i];
              return _GoalChip(goal: g, onTap: () => context.push('${AppRoutes.goalDetail}?id=${g.id}'));
            },
          ),
        ),
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  final UserGoalPlanModel goal;
  final VoidCallback onTap;

  const _GoalChip({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeThemeA.cardRadius),
        child: Ink(
          width: 210,
          padding: const EdgeInsets.all(16),
          decoration: HomeThemeA.cardDecoration(context, shadowTint: goal.color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: HomeThemeA.iconCircleDecoration(context),
                    child: Icon(
                      PhosphorIcons.flag,
                      size: 16,
                      color: HomeThemeA.of(context).primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.cardTitle(size: 13, color: HomeThemeA.of(context).textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (goal.progressPercent / 100).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: HomeThemeA.of(context).borderLight,
                  color: HomeThemeA.of(context).primary,
                ),
              ),
              const Spacer(),
              Text(
                '${CurrencyFormatter.format(goal.accumulatedAmount)} • ${goal.progressPercent.toStringAsFixed(0)}%',
                style: ThemeAType.muted(size: 11, color: HomeThemeA.of(context).textMuted),
              ),
              if (goal.annualReturnRate > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${goal.annualReturnRate.toStringAsFixed(0)}% p.a.',
                  style: ThemeAType.label(size: 10, color: HomeThemeA.of(context).positive),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void showGoalDueDialog(BuildContext context, UserGoalPlanModel goal) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.savings_rounded, color: goal.color, size: 36),
      title: Text('${goal.title} — installment due'),
      content: Text(
        'Your monthly savings of ${CurrencyFormatter.format(goal.monthlyContribution)} is due. '
        'Pay now to keep your goal on track.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: HomeThemeA.primary),
          onPressed: () {
            Navigator.pop(ctx);
            context.push('${AppRoutes.goalDetail}?id=${goal.id}');
          },
          child: const Text('Pay Now'),
        ),
      ],
    ),
  );
}
