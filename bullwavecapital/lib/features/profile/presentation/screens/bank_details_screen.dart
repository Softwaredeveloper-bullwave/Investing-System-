import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../kyc/presentation/provider/bank_verification_provider.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BankVerificationProvider>().hydrateFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bank = context.watch<BankVerificationProvider>();
    final colors = context.appColors;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Bank Details'),
      body: bank.isHydrating
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              children: [
                if (bank.isVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_outlined, color: AppColors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verified via Cashfree',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                              ),
                              Text(
                                'Bank account and PAN verified for trading & payouts.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoCard(
                    items: [
                      _InfoRow('Account Holder', bank.accountHolderName),
                      _InfoRow('Bank Name', bank.bankName),
                      _InfoRow('Account Number', bank.maskedAccountNumber),
                      _InfoRow('IFSC Code', bank.ifscCode),
                      _InfoRow('PAN', bank.panNumber),
                      if (bank.nameAtBank.isNotEmpty)
                        _InfoRow('Name at Bank', bank.nameAtBank),
                      if (bank.panRegisteredName.isNotEmpty)
                        _InfoRow('PAN Registered Name', bank.panRegisteredName),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.bankVerification),
                    child: const Text('Update Bank Details'),
                  ),
                ] else ...[
                  Icon(Icons.account_balance_outlined, size: 56, color: colors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No bank account linked',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Link and verify your bank account with Cashfree to buy stocks, invest, and withdraw.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Link Bank Account',
                    onPressed: () => context.push(AppRoutes.bankVerification),
                  ),
                ],
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;

  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: Theme.of(context).textTheme.bodyMedium),
                    Flexible(
                      child: Text(
                        item.value,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
