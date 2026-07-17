import 'package:flutter/material.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/investment_model.dart';

class InvestmentDetailsScreen extends StatefulWidget {
  const InvestmentDetailsScreen({super.key});

  @override
  State<InvestmentDetailsScreen> createState() => _InvestmentDetailsScreenState();
}

class _InvestmentDetailsScreenState extends State<InvestmentDetailsScreen> {
  InvestmentDetailModel? _investment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await BullwaveApi.instance.getMyInvestments();
      if (mounted) {
        setState(() {
          _investment = list.isNotEmpty ? list.first : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Investment Details'),
        body: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMd),
          child: LoadingList(itemCount: 3),
        ),
      );
    }

    final investment = _investment;
    if (investment == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Investment Details'),
        body: const Center(child: Text('No investments yet')),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Investment Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  children: [
                    _DetailRow(label: 'Investment ID', value: investment.id),
                    _DetailRow(label: 'Amount', value: CurrencyFormatter.format(investment.amount)),
                    _DetailRow(label: 'Date', value: DateFormatter.display(investment.date)),
                    _DetailRow(
                      label: 'Monthly Returns',
                      value: CurrencyFormatter.format(investment.monthlyReturn),
                      valueColor: AppColors.accent,
                    ),
                    _DetailRow(label: 'Status', value: investment.status, valueColor: AppColors.success),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Text('Documents', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.paddingSm),
            ...investment.documents.map(
              (doc) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                  title: Text(doc),
                  trailing: const Icon(Icons.download_outlined),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading $doc...')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            PrimaryButton(
              label: 'Download Receipt',
              icon: Icons.receipt_long,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipt downloaded successfully')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
