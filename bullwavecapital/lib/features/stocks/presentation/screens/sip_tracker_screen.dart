import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';

class SipTrackerScreen extends StatefulWidget {
  const SipTrackerScreen({super.key});

  @override
  State<SipTrackerScreen> createState() => _SipTrackerScreenState();
}

class _SipTrackerScreenState extends State<SipTrackerScreen> {
  final _symbolController = TextEditingController(text: 'RELIANCE');
  final _amountController = TextEditingController(text: '5000');
  final _installmentsController = TextEditingController(text: '12');
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<StockMarketProvider>().ensureLoaded();
    if (!mounted) return;
    await context.read<StockFeaturesProvider>().refreshSipPlans();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createSip() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final installments = int.tryParse(_installmentsController.text.trim()) ?? 12;
    if (symbol.isEmpty || amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter symbol and amount (min ₹100)')),
      );
      return;
    }

    if (!await ensureBankVerified(context)) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    final features = context.read<StockFeaturesProvider>();
    final ok = await features.createSip(
      symbol: symbol,
      monthlyAmount: amount,
      totalInstallments: installments,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'SIP started for $symbol' : (features.tradeError ?? 'Failed to create SIP')),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'SIP Tracker'),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: LoadingList(itemCount: 3, itemHeight: 100),
            )
          : RefreshIndicator(
              color: AppColors.brandOrange,
              onRefresh: _load,
              child: Consumer2<StockFeaturesProvider, StockMarketProvider>(
                builder: (context, features, market, _) {
                  final plans = features.sipPlans;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _CreateSipCard(
                        symbolController: _symbolController,
                        amountController: _amountController,
                        installmentsController: _installmentsController,
                        isSaving: _isSaving,
                        suggestions: market.trendingStocks.take(5).map((s) => s.symbol).toList(),
                        onCreate: _createSip,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Active SIPs (${plans.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (plans.isEmpty)
                        _EmptySip(colors: colors)
                      else
                        ...plans.map((sip) => _SipCard(sip: sip, colors: colors)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _CreateSipCard extends StatelessWidget {
  final TextEditingController symbolController;
  final TextEditingController amountController;
  final TextEditingController installmentsController;
  final bool isSaving;
  final List<String> suggestions;
  final VoidCallback onCreate;

  const _CreateSipCard({
    required this.symbolController,
    required this.amountController,
    required this.installmentsController,
    required this.isSaving,
    required this.suggestions,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start SIP', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: symbolController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Stock symbol',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                onPressed: () => symbolController.text = s,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monthly (₹)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: installmentsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Months',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onCreate,
              icon: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.savings_outlined),
              label: const Text('Start SIP', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _SipCard extends StatelessWidget {
  final SipPlanModel sip;
  final AppThemeExtension colors;

  const _SipCard({required this.sip, required this.colors});

  @override
  Widget build(BuildContext context) {
    final progress = sip.totalInstallments > 0
        ? (sip.installmentsDone / sip.totalInstallments).clamp(0.0, 1.0)
        : 0.0;
    final gain = sip.currentValue - sip.totalInvested;
    final isPositive = gain >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sip.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    Text(sip.name, style: TextStyle(color: colors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${CurrencyFormatter.format(sip.monthlyAmount)}/mo',
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.brandOrange,
              backgroundColor: colors.surfaceSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sip.installmentsDone}/${sip.totalInstallments} installments',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              Text(
                'Next: ${DateFormatter.display(sip.nextDate)}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invested ${CurrencyFormatter.format(sip.totalInvested)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${CurrencyFormatter.format(sip.currentValue)} (${isPositive ? '+' : ''}${CurrencyFormatter.format(gain)})',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isPositive ? AppColors.green : AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySip extends StatelessWidget {
  final AppThemeExtension colors;

  const _EmptySip({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 44, color: colors.textMuted),
          const SizedBox(height: 12),
          Text('No SIPs yet', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            'Start a monthly SIP above to invest automatically in your favourite stocks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
