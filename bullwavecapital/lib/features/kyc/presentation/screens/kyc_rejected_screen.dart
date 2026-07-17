import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/kyc_flow_provider.dart';

/// Matches backend `kyc.constants.KYC_WRONG_INFO_REJECTION_REASON`.
const kycWrongInfoMessage =
    'Your KYC was rejected due to wrong information. '
    'Please resubmit with correct PAN details and clear photos.';

class KycRejectedScreen extends StatelessWidget {
  const KycRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycFlowProvider>();
    final colors = context.appColors;
    final apiReason = kyc.manualStatus.rejectionReason.trim();
    final displayReason = apiReason.isNotEmpty ? apiReason : kycWrongInfoMessage;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'KYC Rejected'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel_outlined, size: 44, color: AppColors.red),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification rejected',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  displayReason,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.kycSubmit),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
                  child: const Text('Resubmit KYC', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
