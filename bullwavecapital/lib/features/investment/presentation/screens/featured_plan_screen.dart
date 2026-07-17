import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../../../models/investment_model.dart';
import '../provider/featured_plan_provider.dart';

class FeaturedPlanScreen extends StatefulWidget {
  final String planId;
  final InvestmentPlanModel? initialPlan;

  const FeaturedPlanScreen({
    super.key,
    required this.planId,
    this.initialPlan,
  });

  @override
  State<FeaturedPlanScreen> createState() => _FeaturedPlanScreenState();
}

class _FeaturedPlanScreenState extends State<FeaturedPlanScreen> {
  late final FeaturedPlanProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = FeaturedPlanProvider(planId: widget.planId, initialPlan: widget.initialPlan);
    WidgetsBinding.instance.addPostFrameCallback((_) => _provider.load());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _payAndInvest() async {
    if (!await ensureBankVerified(context)) return;
    if (!mounted) return;

    final kyc = context.read<KycFlowProvider>();
    final message = await _provider.payAndInvest(kyc);
    if (!mounted) return;

    if (message != null) {
      if (message.contains('Complete payment')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.green),
      );
      context.push(AppRoutes.investmentDetails);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'Featured Plan'),
        body: Consumer<FeaturedPlanProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(AppDimensions.paddingMd),
                child: LoadingList(itemCount: 4, itemHeight: 80),
              );
            }

            final plan = provider.plan;
            if (plan == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    provider.error ?? 'Plan not found.',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final maxAmount = plan.minimumInvestment * 5;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Featured',
                              style: TextStyle(color: AppColors.brandOrange, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        plan.name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.72), height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailGrid(
                  items: [
                    _DetailItem(
                      icon: Icons.savings_outlined,
                      label: 'Min. Investment',
                      value: CurrencyFormatter.format(plan.minimumInvestment),
                    ),
                    _DetailItem(
                      icon: Icons.trending_up,
                      label: 'Monthly Return',
                      value: plan.monthlyReturnLabel,
                    ),
                    _DetailItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Payout',
                      value: 'Monthly to wallet',
                    ),
                    _DetailItem(
                      icon: Icons.verified_user_outlined,
                      label: 'Risk Profile',
                      value: 'Moderate',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DarkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Investment Amount',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      MoneyText(
                        amount: CurrencyFormatter.format(provider.investmentAmount),
                        fontSize: 32,
                        color: Colors.white,
                      ),
                      Slider(
                        value: provider.investmentAmount.clamp(plan.minimumInvestment, maxAmount),
                        min: plan.minimumInvestment,
                        max: maxAmount,
                        divisions: 20,
                        activeColor: AppColors.brandOrange,
                        inactiveColor: Colors.white12,
                        onChanged: provider.setAmount,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Min ${CurrencyFormatter.formatCompact(plan.minimumInvestment)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            'Max ${CurrencyFormatter.formatCompact(maxAmount)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DarkCard(
                  child: plan.hasFixedMonthlyReturn
                      ? _ReturnRow(
                          label: 'Est. monthly return',
                          value: CurrencyFormatter.format(provider.minMonthlyReturn),
                          sub: plan.monthlyReturnLabel.replaceAll(' monthly', ''),
                          highlight: true,
                        )
                      : Column(
                          children: [
                            _ReturnRow(
                              label: 'Est. monthly return (min)',
                              value: CurrencyFormatter.format(provider.minMonthlyReturn),
                              sub: '${plan.monthlyReturnMin.toStringAsFixed(2)}%',
                            ),
                            const Divider(color: Colors.white12, height: 24),
                            _ReturnRow(
                              label: 'Est. monthly return (max)',
                              value: CurrencyFormatter.format(provider.maxMonthlyReturn),
                              sub: '${plan.monthlyReturnMax.toStringAsFixed(2)}%',
                              highlight: true,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _DarkCard(
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: AppColors.brandOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wallet Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(
                              CurrencyFormatter.format(provider.walletBalance),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      if (provider.shortfall > 0)
                        Text(
                          'Need ${CurrencyFormatter.formatCompact(provider.shortfall)} more',
                          style: const TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Payment Method',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                ...['UPI', 'Debit Card', 'Credit Card', 'Net Banking'].map(
                  (method) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFF151A21),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: provider.paymentMethod == method
                                ? AppColors.brandOrange.withValues(alpha: 0.6)
                                : Colors.white12,
                          ),
                        ),
                        title: Text(method, style: const TextStyle(color: Colors.white)),
                        trailing: provider.paymentMethod == method
                            ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                            : const Icon(Icons.circle_outlined, color: Colors.white24),
                        onTap: () => provider.setPaymentMethod(method),
                      ),
                    ),
                  ),
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
                    ),
                    child: Text(provider.error!, style: const TextStyle(color: AppColors.red, height: 1.4)),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: provider.isPaying ? 'Processing…' : 'Pay & Invest',
                  icon: Icons.lock_outline,
                  isLoading: provider.isPaying,
                  onPressed: provider.isPaying ? null : _payAndInvest,
                ),
                const SizedBox(height: 10),
                Text(
                  'Funds are allocated to your plan after payment. Returns are credited monthly to your wallet.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final List<_DetailItem> items;

  const _DetailGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151A21),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: AppColors.brandOrange, size: 20),
                  const Spacer(),
                  Text(item.label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DarkCard extends StatelessWidget {
  final Widget child;

  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: const Color(0xFF151A21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({required this.icon, required this.label, required this.value});
}

class _ReturnRow extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool highlight;

  const _ReturnRow({
    required this.label,
    required this.value,
    required this.sub,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: highlight ? AppColors.green : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (highlight ? AppColors.green : Colors.white).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            sub,
            style: TextStyle(
              color: highlight ? AppColors.green : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
