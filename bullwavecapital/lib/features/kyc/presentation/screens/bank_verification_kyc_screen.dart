import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/bank_form_widgets.dart';
import '../widgets/kyc_widgets.dart';

class BankVerificationKycScreen extends StatefulWidget {
  const BankVerificationKycScreen({super.key});

  @override
  State<BankVerificationKycScreen> createState() => _BankVerificationKycScreenState();
}

class _BankVerificationKycScreenState extends State<BankVerificationKycScreen> {
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _confirmController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final kyc = context.read<KycFlowProvider>();
      final name = kyc.status.panName.isNotEmpty
          ? kyc.status.panName
          : (auth.user?.name ?? '');
      if (name.isNotEmpty && _nameController.text.isEmpty) {
        _nameController.text = name;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _confirmController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await context.read<KycFlowProvider>().verifyBank(
          accountHolderName: _nameController.text,
          accountNumber: _accountController.text,
          confirmAccountNumber: _confirmController.text,
          ifsc: _ifscController.text,
        );
    if (mounted && ok) setState(() => _verified = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Bank Verification'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          final s = kyc.status;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Verify bank account via Cashfree',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text('Real-time validation against NPCI / bank records.'),
              const SizedBox(height: 24),
              if (!_verified) ...[
                AppTextField(
                  controller: _nameController,
                  label: 'Account Holder Name',
                  hint: 'As per bank records',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _accountController,
                  label: 'Account Number',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmController,
                  label: 'Confirm Account Number',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _ifscController,
                  label: 'IFSC Code',
                  inputFormatters: [IfscInputFormatter(), LengthLimitingTextInputFormatter(11)],
                  onChanged: (v) => _ifscController.value = _ifscController.value.copyWith(
                    text: v.toUpperCase(),
                    selection: TextSelection.collapsed(offset: v.length),
                  ),
                ),
                if (kyc.error != null) ...[
                  const SizedBox(height: 16),
                  KycErrorBanner(message: kyc.error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: kyc.isLoading ? 'Verifying…' : 'Verify Bank Account',
                  onPressed: kyc.isLoading ? null : _verify,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_rounded, color: AppColors.green),
                          SizedBox(width: 8),
                          Text('Bank Verified', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Row('Bank', s.bankName),
                      _Row('Branch', s.bankBranch),
                      _Row('Account Holder', s.accountHolderName),
                      _Row('Account', s.bankAccountMasked),
                      _Row('IFSC', s.ifsc),
                      _Row('Status', s.bankStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue to Name Match',
                  onPressed: () => context.push(AppRoutes.nameMatch),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
