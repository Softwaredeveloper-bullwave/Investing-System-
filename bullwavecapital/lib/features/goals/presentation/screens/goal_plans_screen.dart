import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/goal_plan_model.dart';
import '../../data/goal_return_tiers.dart';
import '../provider/goal_plan_provider.dart';
import '../widgets/goal_return_widgets.dart';

class GoalPlansScreen extends StatefulWidget {
  const GoalPlansScreen({super.key});

  @override
  State<GoalPlansScreen> createState() => _GoalPlansScreenState();
}

class _GoalPlansScreenState extends State<GoalPlansScreen> {
  String? _selectedCategory;

  static const _categories = [
    _CategoryMeta('house', 'Home', Icons.home_rounded, Color(0xFF9333EA)),
    _CategoryMeta('education', 'Education', Icons.school_rounded, Color(0xFF10B981)),
    _CategoryMeta('marriage', 'Marriage', Icons.favorite_rounded, Color(0xFFEC4899)),
    _CategoryMeta('vehicle', 'Vehicle', Icons.directions_car_rounded, Color(0xFFF59E0B)),
    _CategoryMeta('retirement', 'Retirement', Icons.elderly_rounded, Color(0xFF6366F1)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalPlanProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Goal Plans'),
      body: Consumer<GoalPlanProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.templates.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandPink));
          }

          final templates = _selectedCategory == null
              ? provider.templates
              : provider.templates.where((t) => t.category == _selectedCategory).toList();

          return RefreshIndicator(
            color: AppColors.brandPink,
            onRefresh: provider.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _HeroBanner(returnTiers: provider.returnTiers),
                if (provider.error != null) ...[
                  const SizedBox(height: 14),
                  PremiumAlertBanner(
                    message: provider.error!,
                    type: PremiumAlertType.warning,
                    actionLabel: 'Retry',
                    onAction: provider.load,
                  ),
                ],
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Choose a goal',
                  subtitle: 'Pick a life milestone and start saving monthly',
                ),
                const SizedBox(height: 14),
                _CategoryChipRow(
                  categories: _categories,
                  selected: _selectedCategory,
                  onSelected: (category) {
                    setState(() {
                      _selectedCategory = _selectedCategory == category ? null : category;
                    });
                  },
                ),
                const SizedBox(height: 18),
                if (templates.isEmpty)
                  _EmptyFilterState(
                    onClear: () => setState(() => _selectedCategory = null),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return _TemplateCard(
                        template: template,
                        onTap: () => context.push('${AppRoutes.createGoal}?category=${template.category}'),
                      );
                    },
                  ),
                if (provider.goals.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'Your goals',
                    subtitle: '${provider.goals.length} active plan${provider.goals.length == 1 ? '' : 's'}',
                    actionLabel: provider.dueGoals.isNotEmpty ? '${provider.dueGoals.length} due' : null,
                    actionColor: provider.dueGoals.isNotEmpty ? AppColors.red : null,
                  ),
                  const SizedBox(height: 14),
                  ...provider.goals.map(
                    (goal) => _GoalProgressCard(
                      goal: goal,
                      onTap: () => context.push('${AppRoutes.goalDetail}?id=${goal.id}'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryMeta {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryMeta(this.id, this.label, this.icon, this.color);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Color? actionColor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12.5, color: colors.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (actionColor ?? AppColors.brandCyan).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (actionColor ?? AppColors.brandCyan).withValues(alpha: 0.3)),
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: actionColor ?? AppColors.brandCyan,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final List<GoalReturnTierModel> returnTiers;

  const _HeroBanner({required this.returnTiers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1035),
            Color(0xFF3B1A8C),
            Color(0xFF5B25FE),
          ],
        ),
        border: Border.all(color: AppColors.brandPrimaryLight.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Up to 16% p.a.',
                      style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.flag_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Smart Goal Investing',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save monthly. Earn tiered returns. Withdraw anytime.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          GoalReturnTiersStrip(tiers: returnTiers, compact: true),
        ],
      ),
    );
  }
}

class _CategoryChipRow extends StatelessWidget {
  final List<_CategoryMeta> categories;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _CategoryChipRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selected == cat.id;

          return ScaleTap(
            onTap: () => onSelected(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          cat.color.withValues(alpha: 0.35),
                          cat.color.withValues(alpha: 0.15),
                        ],
                      )
                    : null,
                color: isSelected ? null : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? cat.color.withValues(alpha: 0.55) : colors.border.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 15, color: isSelected ? cat.color : colors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final GoalTemplateModel template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ScaleTap(
      onTap: onTap,
      child: GlassCard(
        radius: 20,
        glow: true,
        glowColor: template.color,
        padding: const EdgeInsets.all(14),
        gradientOverlay: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            template.color.withValues(alpha: 0.14),
            colors.surface.withValues(alpha: 0.92),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        template.color.withValues(alpha: 0.28),
                        template.color.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: template.color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(template.iconData, color: template.color, size: 22),
                ),
                const Spacer(),
                GoalReturnBadge(
                  annualReturnRate: GoalReturnTiersCatalog.annualRateForMonthly(template.suggestedMonthly),
                  compact: true,
                ),
              ],
            ),
            const Spacer(),
            Text(
              template.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: template.color,
                fontSize: 15.5,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              template.tagline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.35,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'From ₹500/mo',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: template.color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyFilterState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(Icons.filter_list_off_rounded, color: colors.textMuted, size: 32),
          const SizedBox(height: 10),
          Text(
            'No goals in this category',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onClear, child: const Text('Show all goals')),
        ],
      ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  final UserGoalPlanModel goal;
  final VoidCallback onTap;

  const _GoalProgressCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = (goal.progressPercent / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScaleTap(
        onTap: onTap,
        child: GlassCard(
          radius: 18,
          glow: goal.isDue,
          glowColor: goal.isDue ? AppColors.red : goal.color,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.flag_rounded, color: goal.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                  ),
                  GoalReturnBadge(annualReturnRate: goal.annualReturnRate, compact: true),
                  if (goal.isDue) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Due',
                        style: TextStyle(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: goal.color.withValues(alpha: 0.12),
                  color: goal.color,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${CurrencyFormatter.format(goal.accumulatedAmount)} of ${CurrencyFormatter.format(goal.targetAmount)}',
                      style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${goal.progressPercent.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: goal.color,
                    ),
                  ),
                ],
              ),
              if (goal.returnsEarned > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '+${CurrencyFormatter.format(goal.returnsEarned)} returns earned',
                  style: GoogleFonts.inter(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
