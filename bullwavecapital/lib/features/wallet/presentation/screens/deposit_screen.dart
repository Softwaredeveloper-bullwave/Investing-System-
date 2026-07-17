import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  String _paymentMethod = 'UPI';
  String _statusMessage = '';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount (min ₹1)')),
      );
      return;
    }

    final kyc = context.read<KycFlowProvider>();
    final session = await kyc.createPayment(amount);
    if (!mounted || session == null) return;

    if (session.devMode && session.success) {
      context.push('${AppRoutes.depositSuccess}?amount=$amount');
      return;
    }

    setState(() {
      _statusMessage =
          'Payment initiated via Cashfree ($_paymentMethod).\n'
          'Order: ${session.orderId}\n'
          'Complete payment using session ${session.paymentSessionId.isNotEmpty ? session.paymentSessionId.substring(0, 8) : '…'}…';
    });

    if (session.paymentSessionId.isNotEmpty) {
      // Cashfree PG SDK can be wired here with paymentSessionId + environment.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cashfree checkout ready (${session.environment}). Integrate PG SDK with session ID.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Add Money'),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _amountController,
              label: 'Amount',
              hint: 'Enter amount in ₹',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Text('Payment Method', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimensions.paddingSm),
            ...['UPI', 'Debit Card', 'Credit Card', 'Net Banking'].map(
              (method) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(method),
                  trailing: _paymentMethod == method
                      ? const Icon(Icons.check_circle, color: AppColors.green)
                      : null,
                  onTap: () => setState(() => _paymentMethod = method),
                ),
              ),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_statusMessage, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
            const Spacer(),
            Consumer<KycFlowProvider>(
              builder: (context, kycFlow, _) => Column(
                children: [
                  PrimaryButton(
                    label: kycFlow.isLoading ? 'Processing…' : 'Pay with Cashfree',
                    onPressed: kycFlow.isLoading ? null : _proceed,
                  ),
                  if (kycFlow.error != null) ...[
                    const SizedBox(height: 8),
                    Text(kycFlow.error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
