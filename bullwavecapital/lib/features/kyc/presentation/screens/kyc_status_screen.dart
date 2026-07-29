import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';

/// Entry point for the "KYC" section from Profile. This used to show the
/// legacy Cashfree flow (PAN + bank + name-match), which the backend no
/// longer treats as the real verification path — the actual, working flow
/// is the manual PAN submission (`/kyc/submit`, reviewed by admin or
/// instantly by Eko).
///
/// This screen only triggers loading the real (manual) status —
/// it does NOT navigate itself. The router's top-level `redirect` (in
/// app_router.dart) reacts to the resulting notifyListeners() and sends the
/// user to the matching screen (submit/pending/rejected) declaratively.
/// Having this screen *also* call context.go() used to race the router's own
/// refreshListenable-triggered redirect and caused
/// "AnimationController.dispose() called more than once" crashes from two
/// competing page transitions firing on the same navigation. If the user is
/// already verified, no redirect fires and this screen just shows the
/// verified summary below.
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
      context.read<KycFlowProvider>().loadManualStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycFlowProvider>();
    final colors = context.appColors;
    final status = kyc.manualStatus;

    // Still loading, or about to be redirected by _loadAndRoute — show a
    // spinner rather than any flow-specific content.
    if (!kyc.statusLoaded || !status.isVerified) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'KYC Verification'),
        body: const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      );
    }

    final req = status.latestRequest;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'KYC Verification'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppDecorations.glassCard(context),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, size: 44, color: AppColors.green),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You’re verified',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your KYC is complete. You have full access to invest and withdraw.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const KycStatusBadge(status: 'verified'),
                ],
              ),
            ),
            if (req != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'PAN', value: req.panNumber),
                    _InfoRow(label: 'Name', value: req.fullName),
                    if (req.reviewedAt != null)
                      _InfoRow(label: 'Verified on', value: req.reviewedAt!.split('T').first),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
