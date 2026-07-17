import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../provider/wallet_provider.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amountController = TextEditingController();
  String _payoutStatus = '';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Withdraw'),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Balance: ${CurrencyFormatter.format(wallet.wallet.balance)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            AppTextField(
              controller: _amountController,
              label: 'Enter Amount',
              hint: 'Enter withdrawal amount',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Text(
              'Withdrawals are sent to your KYC-verified bank account via Cashfree Payouts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_payoutStatus.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Status: $_payoutStatus', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
            const Spacer(),
            Consumer<KycFlowProvider>(
              builder: (context, kyc, _) => PrimaryButton(
                label: kyc.isLoading ? 'Submitting…' : 'Withdraw to Bank',
                onPressed: kyc.isLoading
                    ? null
                    : () async {
                        final amount = double.tryParse(_amountController.text) ?? 0;
                        if (amount <= 0) {
                          AppSnackbar.error(context, 'Enter valid amount');
                          return;
                        }
                        final result = await kyc.withdraw(amount);
                        if (!context.mounted || result == null) return;
                        await wallet.loadData();
                        if (!context.mounted) return;
                        setState(() => _payoutStatus = result.status);
                        await CustomDialog.showSuccess(
                          context,
                          title: 'Withdrawal Submitted',
                          message:
                              '${CurrencyFormatter.format(amount)} • ${result.status}\nRef: ${result.referenceId}',
                          onDone: () => context.pop(),
                        );
                      },
              ),
            ),
            if (context.watch<KycFlowProvider>().error != null) ...[
              const SizedBox(height: 8),
              Text(
                context.watch<KycFlowProvider>().error!,
                style: const TextStyle(color: AppColors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
