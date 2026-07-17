import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/kyc_flow_provider.dart';

class KycPendingScreen extends StatefulWidget {
  const KycPendingScreen({super.key});

  @override
  State<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends State<KycPendingScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
      _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final kyc = context.read<KycFlowProvider>();
    await kyc.loadManualStatus();
    if (!mounted) return;
    if (kyc.isFullyVerified) {
      context.go(AppRoutes.home);
    } else if (kyc.manualStatus.isRejected) {
      context.go(AppRoutes.kycRejected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycFlowProvider>();
    final colors = context.appColors;
    final req = kyc.manualStatus.latestRequest;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'KYC Verification',
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
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
                      color: AppColors.brandOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      size: 44,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verification under review',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We’ve received your PAN details. Our team is reviewing your documents.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _StepRow(
                          title: 'Submitted',
                          subtitle: 'We received your KYC request',
                          done: true,
                        ),
                        _StepRow(
                          title: 'Under review',
                          subtitle: 'Checking PAN details & photos',
                          done: true,
                        ),
                        _StepRow(
                          title: 'Approved',
                          subtitle: 'Unlock trading & portfolio',
                          done: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (req != null)
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
                      'Submitted details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'PAN', value: req.panNumber),
                    _InfoRow(label: 'Name', value: req.fullName),
                    _InfoRow(label: 'Submitted', value: req.createdAt.split('T').first),
                  ],
                ),
              ),
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
                    'What happens next?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Approval usually takes a few minutes. This screen checks automatically every few seconds — or tap refresh (top right).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                  if (kyc.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      kyc.error!,
                      style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            if (kyc.isLoading) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;

  const _StepRow({required this.title, required this.subtitle, required this.done});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final icon = done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded;
    final iconColor = done ? AppColors.green : colors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
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
