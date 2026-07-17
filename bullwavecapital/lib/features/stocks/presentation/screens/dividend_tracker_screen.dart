import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_features_provider.dart';

class DividendTrackerScreen extends StatefulWidget {
  const DividendTrackerScreen({super.key});

  @override
  State<DividendTrackerScreen> createState() => _DividendTrackerScreenState();
}

class _DividendTrackerScreenState extends State<DividendTrackerScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<StockFeaturesProvider>().refreshDividends();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Dividend Tracker'),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: LoadingList(itemCount: 4, itemHeight: 88),
            )
          : RefreshIndicator(
              color: AppColors.brandOrange,
              onRefresh: _load,
              child: Consumer<StockFeaturesProvider>(
                builder: (context, features, _) {
                  final dividends = features.dividends;
                  final totalPaid = dividends
                      .where((d) => d.status.toLowerCase() == 'paid')
                      .fold(0.0, (sum, d) => sum + d.totalPayout);
                  final totalUpcoming = dividends
                      .where((d) => d.status.toLowerCase() == 'upcoming')
                      .fold(0.0, (sum, d) => sum + d.totalPayout);

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (dividends.isNotEmpty)
                        _SummaryCard(
                          colors: colors,
                          totalPaid: totalPaid,
                          totalUpcoming: totalUpcoming,
                          count: dividends.length,
                        ),
                      if (dividends.isEmpty)
                        _EmptyState(colors: colors)
                      else
                        ...dividends.map((d) => _DividendCard(dividend: d, colors: colors)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AppThemeExtension colors;
  final double totalPaid;
  final double totalUpcoming;
  final int count;

  const _SummaryCard({
    required this.colors,
    required this.totalPaid,
    required this.totalUpcoming,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.heroCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count dividend records',
            style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Received', value: CurrencyFormatter.format(totalPaid), color: AppColors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Upcoming',
                  value: CurrencyFormatter.format(totalUpcoming),
                  color: AppColors.brandOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DividendCard extends StatelessWidget {
  final DividendModel dividend;
  final AppThemeExtension colors;

  const _DividendCard({required this.dividend, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isPaid = dividend.status.toLowerCase() == 'paid';
    final accent = isPaid ? AppColors.green : AppColors.brandOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                      dividend.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(dividend.name, style: TextStyle(color: colors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  dividend.status,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatDecimal(dividend.totalPayout),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: accent),
          ),
          Text(
            '${CurrencyFormatter.formatDecimal(dividend.amountPerShare)}/share × ${dividend.sharesHeld} shares',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Ex-date: ${DateFormatter.display(dividend.exDate)} • Pay: ${DateFormatter.display(dividend.paymentDate)}',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppThemeExtension colors;

  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          Icon(Icons.payments_outlined, size: 48, color: colors.textMuted),
          const SizedBox(height: 12),
          Text('No dividends yet', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            'Buy stocks in your portfolio to track dividend payouts here. Pull down to sync.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
