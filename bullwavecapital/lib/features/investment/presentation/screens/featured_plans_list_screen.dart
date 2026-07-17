import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/portfolio_card.dart';
import '../../../../models/investment_model.dart';
import '../../data/featured_plans_catalog.dart';
import '../../../home/presentation/provider/home_provider.dart';

class FeaturedPlansListScreen extends StatefulWidget {
  const FeaturedPlansListScreen({super.key});

  @override
  State<FeaturedPlansListScreen> createState() => _FeaturedPlansListScreenState();
}

class _FeaturedPlansListScreenState extends State<FeaturedPlansListScreen> {
  List<InvestmentPlanModel> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final home = context.read<HomeProvider>();
      if (home.featuredPlans.isNotEmpty) {
        _plans = home.featuredPlans;
      } else {
        _plans = await BullwaveApi.instance.getInvestmentPlans();
        _plans = _plans.where((p) => p.isFeatured).toList();
      }
    } catch (_) {
      _plans = FeaturedPlansCatalog.plans;
    }
    if (_plans.isEmpty) _plans = FeaturedPlansCatalog.plans;
    if (mounted) setState(() => _loading = false);
  }

  String _riskFor(String id) {
    switch (id) {
      case 'PLAN003':
        return 'High';
      case 'PLAN002':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  void _openPlan(BuildContext context, InvestmentPlanModel plan) {
    context.push('${AppRoutes.featuredPlan}/${plan.id}', extra: plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Featured Plans'),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: LoadingList(itemCount: 3, itemHeight: 140),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              itemCount: _plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return InvestmentCard(
                  name: plan.name,
                  minimumInvestment: plan.minimumInvestment,
                  annualReturn: plan.annualReturnRate,
                  monthlyReturnMin: plan.monthlyReturnMin,
                  monthlyReturnMax: plan.monthlyReturnMax,
                  risk: _riskFor(plan.id),
                  onTap: () => _openPlan(context, plan),
                );
              },
            ),
    );
  }
}
