import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';

class NameMatchScreen extends StatefulWidget {
  const NameMatchScreen({super.key});

  @override
  State<NameMatchScreen> createState() => _NameMatchScreenState();
}

class _NameMatchScreenState extends State<NameMatchScreen> {
  bool? _passed;

  Future<void> _runMatch() async {
    final ok = await context.read<KycFlowProvider>().runNameMatch();
    if (mounted) setState(() => _passed = ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Name Match'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          final s = kyc.status;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compare PAN & Bank names',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 16),
                _CompareCard(label: 'PAN Name', value: s.panName),
                const SizedBox(height: 12),
                _CompareCard(label: 'Bank Name', value: s.nameAtBank.isNotEmpty ? s.nameAtBank : s.accountHolderName),
                const SizedBox(height: 24),
                if (_passed == true) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.green, size: 40),
                        const SizedBox(height: 8),
                        Text('Verified • ${s.nameMatchResult}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('Match score: ${s.nameMatchScore.toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(label: 'Start Investing', onPressed: () => context.go(AppRoutes.invest)),
                ] else if (_passed == false) ...[
                  KycErrorBanner(
                    message: kyc.error ?? 'Names do not match. Update bank or PAN details and retry.',
                  ),
                  const Spacer(),
                  PrimaryButton(label: 'Retry', onPressed: _runMatch),
                ] else ...[
                  if (kyc.error != null) KycErrorBanner(message: kyc.error!),
                  const Spacer(),
                  PrimaryButton(
                    label: kyc.isLoading ? 'Checking…' : 'Run Name Match',
                    onPressed: kyc.isLoading ? null : _runMatch,
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

class _CompareCard extends StatelessWidget {
  final String label;
  final String value;

  const _CompareCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
