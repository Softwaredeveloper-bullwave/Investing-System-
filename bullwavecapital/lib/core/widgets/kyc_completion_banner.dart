import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';
import '../constants/routes.dart';
import 'premium_ui_kit.dart';

/// Soft prompt to finish KYC before trading or funding — does not block browsing.
class KycCompletionBanner extends StatelessWidget {
  const KycCompletionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycFlowProvider>();
    if (kyc.isFullyVerified) return const SizedBox.shrink();

    return PremiumAlertBanner(
      message: 'Complete KYC to trade stocks, deposit, and withdraw.',
      type: PremiumAlertType.info,
      actionLabel: 'Verify',
      onAction: () => context.push(AppRoutes.kycSubmit),
    );
  }
}
