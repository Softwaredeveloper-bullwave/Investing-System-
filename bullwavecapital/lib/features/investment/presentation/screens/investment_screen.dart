import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/portfolio_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/profile_tile.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../provider/investment_provider.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final _searchController = TextEditingController();
  String _selectedRisk = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvestmentProvider>(
      builder: (context, provider, _) {
        final colors = context.appColors;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invest', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: AppDimensions.paddingMd),
                TextField(
                  controller: _searchController,
                  decoration: AppDecorations.pillSearch(context, hint: 'Search funds & plans'),
                ),
                const SizedBox(height: AppDimensions.paddingMd),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Low Risk', 'Medium Risk', 'High Risk'].map((risk) {
                      final selected = _selectedRisk == risk;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(risk),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedRisk = risk),
                          selectedColor: AppColors.green.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.green,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.green : colors.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingLg),
                RobinhoodCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.plan.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      MoneyText(
                        amount: CurrencyFormatter.format(provider.investmentAmount),
                        fontSize: 32,
                      ),
                      Slider(
                        value: provider.investmentAmount,
                        min: provider.plan.minimumInvestment,
                        max: provider.plan.minimumInvestment * 5,
                        divisions: 20,
                        activeColor: AppColors.green,
                        inactiveColor: colors.border,
                        onChanged: provider.setInvestmentAmount,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _CalcItem(
                              label: 'Monthly Return',
                              value: CurrencyFormatter.format(provider.expectedMonthlyReturn),
                            ),
                          ),
                          Expanded(
                            child: _CalcItem(
                              label: 'Annual Return',
                              value: CurrencyFormatter.format(provider.estimatedAnnualReturn),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingLg),
                PrimaryButton(
                  label: 'Invest Now',
                  isLoading: provider.isLoading,
                  icon: Icons.trending_up,
                  onPressed: () async {
                    if (!await ensureBankVerified(context)) return;
                    if (!context.mounted) return;
                    final router = GoRouter.of(context);
                    final success = await provider.invest();
                    if (!context.mounted) return;
                    if (success) router.push(AppRoutes.investmentDetails);
                  },
                ),
                const SizedBox(height: AppDimensions.paddingLg),
                SectionHeader(title: 'Available Plans'),
                const SizedBox(height: AppDimensions.paddingSm),
                InvestmentCard(
                  name: provider.plan.name,
                  minimumInvestment: provider.plan.minimumInvestment,
                  annualReturn: provider.plan.annualReturnRate,
                  risk: 'Low',
                  onTap: () {},
                ),
                const SizedBox(height: AppDimensions.paddingLg),
                SectionHeader(title: 'FAQ'),
                const SizedBox(height: AppDimensions.paddingSm),
                ...List.generate(
                  provider.faqs.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FaqTile(
                      question: provider.faqs[index].question,
                      answer: provider.faqs[index].answer,
                      isExpanded: provider.faqs[index].isExpanded,
                      onTap: () => provider.toggleFaq(index),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalcItem extends StatelessWidget {
  final String label;
  final String value;
  const _CalcItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}
