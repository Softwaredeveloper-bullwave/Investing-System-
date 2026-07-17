import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../models/fno_status_model.dart';
import '../provider/fno_flow_provider.dart';

class FnoVerificationScreen extends StatefulWidget {
  const FnoVerificationScreen({super.key});

  @override
  State<FnoVerificationScreen> createState() => _FnoVerificationScreenState();
}

class _FnoVerificationScreenState extends State<FnoVerificationScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FnoFlowProvider>().refresh();
    });
  }

  Future<void> _pickAndSubmit(String proofType) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (file == null || !mounted) return;

    final message = await context.read<FnoFlowProvider>().submitDocument(
          proofType: proofType,
          file: file,
        );
    if (!mounted) return;
    if (message != null) {
      _showSnack(message);
      if (context.read<FnoFlowProvider>().isVerified) {
        context.go(AppRoutes.optionChain);
      }
    }
  }

  Future<void> _verifyPortfolio() async {
    final fno = context.read<FnoFlowProvider>();
    final message = await fno.submitPortfolioHolding();
    if (!mounted) return;
    if (message != null) {
      _showSnack(message);
      if (fno.isVerified) {
        context.go(AppRoutes.optionChain);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: CustomAppBar(
        title: 'F&O Verification',
        actions: [
          Consumer<FnoFlowProvider>(
            builder: (context, fno, _) => IconButton(
              tooltip: 'Retry',
              onPressed: fno.isLoading ? null : () => context.read<FnoFlowProvider>().refresh(),
              icon: fno.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
                    )
                  : Icon(Icons.refresh_rounded, color: p.textDark),
            ),
          ),
        ],
      ),
      body: Consumer<FnoFlowProvider>(
        builder: (context, fno, _) {
          if (fno.isLoading && !fno.statusLoaded) {
            return Center(child: CircularProgressIndicator(color: p.primary));
          }

          final options = fno.status.proofOptions.isNotEmpty
              ? fno.status.proofOptions
              : [
                  FnoProofOptionModel(
                    type: 'bank_statement',
                    label: '6-Month Bank Statement',
                    requiresUpload: true,
                  ),
                  FnoProofOptionModel(type: 'form16', label: 'FORM 16', requiresUpload: true),
                  FnoProofOptionModel(type: 'itr', label: 'ITR Form', requiresUpload: true),
                  FnoProofOptionModel(
                    type: 'portfolio_holding',
                    label: '₹50,000 Portfolio Holding',
                    requiresUpload: false,
                  ),
                ];
          final portfolio = fno.status.portfolioValue;
          final minPortfolio = fno.status.minPortfolioValue;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: p.heroCardDecoration(radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable F&O Trading',
                      style: ThemeAType.sectionTitle(size: 18, color: p.heroCardFg),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose one eligibility proof to access Futures & Options. '
                      'Document proofs are sent to admin for email review.',
                      style: ThemeAType.secondary(size: 14, color: p.heroCardMuted),
                    ),
                    if (portfolio > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Portfolio value: ${CurrencyFormatter.format(portfolio)}',
                        style: ThemeAType.label(size: 14, color: p.positive),
                      ),
                    ],
                  ],
                ),
              ),
              if (fno.isPending) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  color: AppColors.yellow,
                  title: 'Under admin review',
                  message:
                      'Your ${fno.status.latestRequest?.proofLabel ?? 'document'} was sent to admin. '
                      'You will be notified once approved and can then trade F&O.',
                ),
              ],
              if (fno.isRejected) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  color: AppColors.red,
                  title: 'Verification rejected',
                  message: fno.status.latestRequest?.rejectionReason ??
                      'Please choose another proof option and resubmit.',
                ),
              ],
              if (fno.error != null) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  color: AppColors.red,
                  title: 'Connection error',
                  message: fno.error!,
                  actionLabel: 'Retry',
                  onAction: fno.isLoading ? null : () => context.read<FnoFlowProvider>().refresh(),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Select one option',
                style: context.typeSection(16),
              ),
              const SizedBox(height: 14),
              ...options.map((option) {
                final icon = _iconFor(option.type);
                final color = _colorFor(option.type);
                final subtitle = option.requiresUpload
                    ? 'Upload photo or scan (PDF as image)'
                    : 'Portfolio must be at least ${CurrencyFormatter.format(minPortfolio)}';
                final onTap = fno.isLoading || fno.isPending
                    ? null
                    : () {
                        if (option.requiresUpload) {
                          _pickAndSubmit(option.type);
                        } else {
                          _verifyPortfolio();
                        }
                      };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProofCard(
                    icon: icon,
                    color: color,
                    title: option.label,
                    subtitle: subtitle,
                    onTap: onTap,
                  ),
                );
              }),
              if (fno.isVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton(
                    onPressed: () => context.go(AppRoutes.optionChain),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.isDark ? p.primary : p.heroCard,
                      foregroundColor: p.isDark ? p.onPrimary : p.heroCardFg,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text(
                      'Open F&O Chain',
                      style: ThemeAType.label(size: 14, color: p.isDark ? p.onPrimary : p.heroCardFg),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'bank_statement':
        return Icons.account_balance_outlined;
      case 'form16':
        return Icons.description_outlined;
      case 'itr':
        return Icons.receipt_long_outlined;
      case 'portfolio_holding':
        return Icons.savings_outlined;
      default:
        return Icons.verified_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'bank_statement':
        return const Color(0xFF6366F1);
      case 'form16':
        return AppColors.blue;
      case 'itr':
        return AppColors.green;
      case 'portfolio_holding':
        return AppColors.yellow;
      default:
        return AppColors.green;
    }
  }
}

class _ProofCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProofCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: p.cardDecoration(radius: 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: p.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThemeAType.cardTitle(size: 16, color: p.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ThemeAType.secondary(size: 14, color: p.textGrey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? p.textGrey : p.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusBanner({
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ThemeAType.cardTitle(size: 15, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: ThemeAType.secondary(size: 14, color: p.textGrey),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: ThemeAType.label(size: 14, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
