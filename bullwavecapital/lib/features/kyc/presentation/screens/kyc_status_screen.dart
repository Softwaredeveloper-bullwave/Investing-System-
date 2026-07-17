import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/kyc_models.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KycFlowProvider>().loadStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: const CustomAppBar(title: 'KYC Verification'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          if (kyc.isLoading && kyc.status == KycStatusModel.empty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandOrange));
          }

          final s = kyc.status;
          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: kyc.loadStatus,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Verification Progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    KycStatusBadge(status: s.overallStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete all steps to start investing and withdrawing.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      KycStepTile(
                        title: 'Mobile Verified',
                        subtitle: s.mobileVerified ? 'OTP verified' : 'Login with phone OTP',
                        completed: s.mobileVerified,
                      ),
                      KycStepTile(
                        title: 'PAN Verified',
                        subtitle: s.panVerified ? '${s.panName} • ${s.panNumberMasked}' : 'Verify PAN with Cashfree',
                        completed: s.panVerified,
                      ),
                      KycStepTile(
                        title: 'Bank Verified',
                        subtitle: s.bankVerified
                            ? '${s.bankName} • ${s.bankAccountMasked}'
                            : 'Link bank account',
                        completed: s.bankVerified,
                      ),
                      KycStepTile(
                        title: 'Name Match Passed',
                        subtitle: s.nameMatchPassed
                            ? '${s.nameMatchResult} (${s.nameMatchScore.toStringAsFixed(0)}%)'
                            : 'Match PAN name with bank records',
                        completed: s.nameMatchPassed,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (kyc.error != null) ...[
                  const SizedBox(height: 16),
                  KycErrorBanner(message: kyc.error!),
                ],
                const SizedBox(height: 24),
                if (!s.panVerified)
                  PrimaryButton(
                    label: 'Verify PAN',
                    onPressed: () => context.push(AppRoutes.panVerification),
                  )
                else if (!s.bankVerified)
                  PrimaryButton(
                    label: 'Verify Bank Account',
                    onPressed: () => context.push(AppRoutes.bankVerificationKyc),
                  )
                else if (!s.nameMatchPassed)
                  PrimaryButton(
                    label: 'Run Name Match',
                    onPressed: () => context.push(AppRoutes.nameMatch),
                  )
                else
                  PrimaryButton(
                    label: 'Start Investing',
                    onPressed: () => context.go(AppRoutes.invest),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}