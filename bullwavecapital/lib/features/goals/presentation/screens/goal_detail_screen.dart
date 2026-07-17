import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/goal_plan_model.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../widgets/goal_return_widgets.dart';
import '../provider/goal_plan_provider.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalPlanProvider>().load();
    });
  }

  UserGoalPlanModel? _goal(GoalPlanProvider p) {
    try {
      return p.goals.firstWhere((g) => g.id == widget.goalId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _payDue(GoalPlanProvider provider) async {
    final kyc = context.read<KycFlowProvider>();
    final msg = await provider.payDueInstallment(widget.goalId, kyc);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  Future<void> _withdraw(GoalPlanProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw to wallet?'),
        content: const Text('Saved amount will move to your BullWave wallet. You can withdraw to bank from Wallet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final msg = await provider.withdrawGoal(widget.goalId);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Goal Details'),
      body: Consumer<GoalPlanProvider>(
        builder: (context, provider, _) {
          final goal = _goal(provider);
          if (goal == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(goal.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Ref ${goal.referenceId}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: (goal.progressPercent / 100).clamp(0, 1),
                  minHeight: 12,
                  backgroundColor: goal.color.withValues(alpha: 0.15),
                  color: goal.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${CurrencyFormatter.format(goal.accumulatedAmount)} saved of ${CurrencyFormatter.format(goal.targetAmount)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GoalReturnBadge(annualReturnRate: goal.annualReturnRate),
                  if (goal.returnsEarned > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${CurrencyFormatter.format(goal.returnsEarned)} earned',
                        style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                ],
              ),
              Text('${goal.progressPercent.toStringAsFixed(0)}% complete • ${goal.installmentsDone}/${goal.totalInstallments} months',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      goal.color.withValues(alpha: 0.12),
                      AppColors.brandPrimary.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: goal.color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Return outlook', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Est. at maturity',
                            value: CurrencyFormatter.format(
                              goal.projectedMaturityValue > 0
                                  ? goal.projectedMaturityValue
                                  : goal.targetAmount,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _MetricTile(
                            label: 'Est. returns',
                            value: CurrencyFormatter.format(goal.projectedReturns),
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _InfoRow(label: 'Monthly installment', value: CurrencyFormatter.format(goal.monthlyContribution)),
              _InfoRow(label: 'Next due', value: goal.nextContributionDate ?? '—'),
              _InfoRow(label: 'Target date', value: goal.targetDate ?? '—'),
              _InfoRow(label: 'Status', value: goal.status.toUpperCase()),
              if (goal.isDue) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This month\'s installment is due. Pay now to stay on track.',
                    style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: provider.isSubmitting ? 'Paying…' : 'Pay This Month\'s Installment',
                  isLoading: provider.isSubmitting,
                  onPressed: provider.isSubmitting ? null : () => _payDue(provider),
                ),
              ],
              if (goal.canWithdraw) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: provider.isSubmitting ? null : () => _withdraw(provider),
                  child: const Text('Withdraw to Wallet'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricTile({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.appColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: highlight ? AppColors.green : context.appColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
