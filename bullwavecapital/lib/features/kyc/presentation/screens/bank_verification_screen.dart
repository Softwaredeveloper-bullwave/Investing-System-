import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/bank_verification_provider.dart';
import '../widgets/bank_form_widgets.dart';

class BankVerificationScreen extends StatefulWidget {
  const BankVerificationScreen({super.key});

  @override
  State<BankVerificationScreen> createState() => _BankVerificationScreenState();
}

class _BankVerificationScreenState extends State<BankVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderController;
  late final TextEditingController _bankController;
  late final TextEditingController _accountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _panController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BankVerificationProvider>();
    _holderController = TextEditingController(text: provider.accountHolderName);
    _bankController = TextEditingController(text: provider.bankName);
    _accountController = TextEditingController(text: provider.accountNumber);
    _ifscController = TextEditingController(text: provider.ifscCode);
    _panController = TextEditingController(text: provider.panNumber);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BankVerificationProvider>().hydrateFromServer();
    });
  }

  @override
  void dispose() {
    _holderController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _panController.dispose();
    super.dispose();
  }

  void _finish() {
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BankVerificationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: provider.step == BankVerificationStep.success
                ? 'Verified'
                : 'Link Bank Account',
            showBack: provider.step != BankVerificationStep.success,
            onBack: () {
              if (provider.step == BankVerificationStep.verify) {
                provider.resetToDetails();
              } else {
                context.pop(false);
              }
            },
          ),
          body: switch (provider.step) {
            BankVerificationStep.details => _DetailsStep(
                formKey: _formKey,
                holderController: _holderController,
                bankController: _bankController,
                accountController: _accountController,
                ifscController: _ifscController,
                panController: _panController,
                provider: provider,
              ),
            BankVerificationStep.verify => _VerifyStep(
                provider: provider,
                onVerified: () {},
              ),
            BankVerificationStep.success => _SuccessStep(onContinue: _finish),
          },
        );
      },
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController holderController;
  final TextEditingController bankController;
  final TextEditingController accountController;
  final TextEditingController ifscController;
  final TextEditingController panController;
  final BankVerificationProvider provider;

  const _DetailsStep({
    required this.formKey,
    required this.holderController,
    required this.bankController,
    required this.accountController,
    required this.ifscController,
    required this.panController,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          color: colors.surfaceSecondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add bank account to invest',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Required before buying stocks or investing in plans.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.progress,
                  minHeight: 4,
                  backgroundColor: colors.border,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              children: [
                const FormSectionHeader(
                  title: 'Bank Details',
                  subtitle: 'Used for deposits, withdrawals & settlements',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: holderController,
                  label: 'Account Holder Name',
                  hint: 'As per bank records',
                  textCapitalization: TextCapitalization.words,
                  onChanged: provider.updateAccountHolder,
                  validator: (v) =>
                      v == null || v.length < 3 ? 'Enter valid name' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: bankController,
                  label: 'Bank Name',
                  hint: 'e.g. HDFC Bank, SBI',
                  onChanged: provider.updateBankName,
                  validator: (v) =>
                      v == null || v.length < 3 ? 'Enter bank name' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: accountController,
                  label: 'Account Number',
                  hint: 'Enter account number',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: provider.updateAccountNumber,
                  validator: (v) =>
                      v == null || v.length < 9 ? 'Enter valid account number' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: ifscController,
                  label: 'IFSC Code',
                  hint: 'e.g. HDFC0001234',
                  inputFormatters: [
                    IfscInputFormatter(),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: provider.updateIfsc,
                  validator: (v) {
                    if (v == null ||
                        !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v)) {
                      return 'Enter valid IFSC code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const FormSectionHeader(
                  title: 'PAN Details',
                  subtitle: 'Mandatory for trading & investments in India',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: panController,
                  label: 'PAN Number',
                  hint: 'e.g. ABCDE1234F',
                  inputFormatters: [
                    PanInputFormatter(),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: provider.updatePan,
                  validator: (v) {
                    if (v == null ||
                        !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v)) {
                      return 'Enter valid PAN number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    provider.proceedToVerify();
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifyStep extends StatelessWidget {
  final BankVerificationProvider provider;
  final VoidCallback onVerified;

  const _VerifyStep({required this.provider, required this.onVerified});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_outlined, color: AppColors.green),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.bankName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            provider.maskedAccountNumber,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SummaryRow(label: 'Account Holder', value: provider.accountHolderName),
                _SummaryRow(label: 'IFSC', value: provider.ifscCode),
                _SummaryRow(label: 'PAN', value: provider.panNumber),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verify your account',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We verify your bank account and PAN in real time using Cashfree Secure ID — '
            'the same verification stack used by leading fintech apps in India.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
          ),
          if (provider.lastError != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
              ),
              child: Text(
                provider.lastError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          const Spacer(),
          if (provider.isVerifying) ...[
            const Center(child: CircularProgressIndicator(color: AppColors.green)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Verifying bank account…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ),
          ] else
            PrimaryButton(
              label: 'Verify Bank & PAN',
              icon: Icons.verified_user_outlined,
              onPressed: () async {
                final result = await provider.verifyAccount();
                if (!context.mounted) return;
                if (!result.success && result.message.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message)),
                  );
                }
              },
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: provider.isVerifying ? null : provider.resetToDetails,
              child: const Text('Edit details'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final VoidCallback onContinue;

  const _SuccessStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.green, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Bank account verified',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your bank account and PAN are verified. You can invest, trade, and withdraw.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          Consumer<BankVerificationProvider>(
            builder: (context, provider, _) {
              if (provider.nameAtBank.isEmpty && provider.panRegisteredName.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.nameAtBank.isNotEmpty)
                      _SummaryRow(label: 'Name at bank', value: provider.nameAtBank),
                    if (provider.panRegisteredName.isNotEmpty)
                      _SummaryRow(label: 'PAN name', value: provider.panRegisteredName),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          PrimaryButton(label: 'Continue', onPressed: onContinue),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
