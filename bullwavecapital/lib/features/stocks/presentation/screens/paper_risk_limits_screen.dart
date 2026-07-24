import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/paper_trading_provider.dart';
import '../widgets/simulation_badge.dart';

/// Risk limits — daily loss cap + max single-position sizing, with today's
/// breach status. Purely advisory: never blocks an order.
class PaperRiskLimitsScreen extends StatefulWidget {
  const PaperRiskLimitsScreen({super.key});

  @override
  State<PaperRiskLimitsScreen> createState() => _PaperRiskLimitsScreenState();
}

class _PaperRiskLimitsScreenState extends State<PaperRiskLimitsScreen> {
  final _maxDailyLossController = TextEditingController();
  final _maxPositionPercentController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _maxDailyLossController.dispose();
    _maxPositionPercentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<PaperTradingProvider>().loadRiskStatus();
    if (!mounted) return;
    final limit = context.read<PaperTradingProvider>().riskStatus.limit;
    _maxDailyLossController.text = limit.maxDailyLoss != null ? limit.maxDailyLoss!.toStringAsFixed(0) : '';
    _maxPositionPercentController.text = limit.maxPositionSizePercent.toStringAsFixed(0);
    setState(() {
      _isActive = limit.isActive;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final maxLoss = double.tryParse(_maxDailyLossController.text.trim());
    final maxPct = double.tryParse(_maxPositionPercentController.text.trim());
    final ok = await context.read<PaperTradingProvider>().updateRiskLimit(
          maxDailyLoss: maxLoss,
          maxPositionSizePercent: maxPct,
          isActive: _isActive,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Risk limits saved.' : 'Could not save risk limits.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Risk Limits'),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(20), child: LoadingList(itemCount: 3, itemHeight: 90))
          : Consumer<PaperTradingProvider>(
              builder: (context, provider, _) {
                final status = provider.riskStatus;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                    const SizedBox(height: 14),
                    if (status.dailyLossBreached)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Daily loss limit breached — today\'s loss is '
                                '${CurrencyFormatter.format(status.dailyLoss)}.',
                                style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppDecorations.card(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Today\'s P&L', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                              Text(
                                CurrencyFormatter.format(status.dailyPnl),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: status.dailyPnl >= 0 ? AppColors.green : AppColors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current equity', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                              Text(CurrencyFormatter.format(status.currentEquity), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (status.positionBreaches.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppDecorations.card(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Position size warnings', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary)),
                            const SizedBox(height: 8),
                            for (final b in status.positionBreaches)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '${b.symbol} is ${b.positionPercent.toStringAsFixed(1)}% of your portfolio '
                                  '(limit ${b.limitPercent.toStringAsFixed(0)}%)',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppDecorations.card(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Enable risk limits', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textSecondary)),
                              Switch(
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                                activeThumbColor: AppColors.brandOrange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _maxDailyLossController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max daily loss (₹)',
                              hintText: 'e.g. 5000',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _maxPositionPercentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max single-position size (% of equity)',
                              hintText: 'e.g. 20',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _save,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Save Limits'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
