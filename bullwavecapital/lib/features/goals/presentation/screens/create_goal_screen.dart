import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/goal_plan_model.dart';
import '../../data/goal_templates_catalog.dart';
import '../widgets/goal_return_widgets.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../provider/goal_plan_provider.dart';

class CreateGoalScreen extends StatefulWidget {
  final String category;

  const CreateGoalScreen({super.key, required this.category});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GoalPlanProvider>();
      GoalTemplateModel? template = GoalTemplatesCatalog.byCategory(widget.category);
      if (template == null) {
        for (final t in provider.templates) {
          if (t.category == widget.category) {
            template = t;
            break;
          }
        }
      }
      template ??= provider.templates.isNotEmpty
          ? provider.templates.first
          : GoalTemplatesCatalog.templates.first;
      provider.selectTemplate(template);
      provider.load();
    });
  }

  Future<void> _start() async {
    final provider = context.read<GoalPlanProvider>();
    final kyc = context.read<KycFlowProvider>();
    final msg = await provider.startGoal(kyc);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (provider.error == null && !msg.contains('Complete payment')) {
        context.pop(true);
      }
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Start Goal Plan'),
      body: Consumer<GoalPlanProvider>(
        builder: (context, provider, _) {
          final t = provider.selectedTemplate;
          if (t == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                leading: CircleAvatar(backgroundColor: t.color.withValues(alpha: 0.15), child: Icon(t.iconData, color: t.color)),
                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(t.tagline),
              ),
              const SizedBox(height: 20),
              _Field(
                label: 'Goal name',
                child: TextFormField(
                  initialValue: provider.title,
                  onChanged: provider.setTitle,
                  decoration: const InputDecoration(hintText: 'My dream home fund'),
                ),
              ),
              _Field(
                label: 'Target amount',
                child: Slider(
                  value: provider.targetAmount.clamp(t.minTarget, 500000),
                  min: t.minTarget,
                  max: 500000,
                  divisions: 20,
                  label: CurrencyFormatter.format(provider.targetAmount),
                  onChanged: provider.setTargetAmount,
                ),
              ),
              Text('Target: ${CurrencyFormatter.format(provider.targetAmount)}', style: TextStyle(color: colors.textSecondary)),
              _Field(
                label: 'Monthly savings',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slider(
                      value: provider.monthlyContribution.clamp(500, 100000),
                      min: 500,
                      max: 100000,
                      divisions: 40,
                      label: CurrencyFormatter.format(provider.monthlyContribution),
                      onChanged: provider.setMonthlyContribution,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyFormatter.format(provider.monthlyContribution),
                            style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary),
                          ),
                        ),
                        GoalReturnBadge(annualReturnRate: provider.selectedAnnualRate),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.selectedTier.rangeLabel,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              GoalProjectionCard(
                monthlyContribution: provider.monthlyContribution,
                durationMonths: provider.durationMonths,
                annualReturnRate: provider.selectedAnnualRate,
                tier: provider.selectedTier,
                accent: t.color,
              ),
              const SizedBox(height: 20),
              _Field(
                label: 'Duration: ${provider.durationMonths} months',
                child: Slider(
                  value: provider.durationMonths.toDouble(),
                  min: t.minDurationMonths.toDouble(),
                  max: t.maxDurationMonths.toDouble(),
                  divisions: t.maxDurationMonths - t.minDurationMonths,
                  onChanged: (v) => provider.setDurationMonths(v.round()),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: colors.surfaceSecondary, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet: ${CurrencyFormatter.format(provider.walletBalance)}', style: TextStyle(fontWeight: FontWeight.w700)),
                    if (provider.shortfall > 0)
                      Text(
                        'First installment needs ${CurrencyFormatter.format(provider.shortfall)} top-up via UPI',
                        style: const TextStyle(color: AppColors.yellow, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: provider.isSubmitting ? 'Processing…' : 'Start Goal & Pay First Installment',
                isLoading: provider.isSubmitting,
                onPressed: provider.isSubmitting ? null : _start,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
