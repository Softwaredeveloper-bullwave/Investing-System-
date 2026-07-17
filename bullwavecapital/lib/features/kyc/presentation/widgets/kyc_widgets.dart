import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';

class KycStepTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool completed;
  final bool isLast;

  const KycStepTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.completed,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: completed ? AppColors.green : colors.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed ? AppColors.green : colors.border,
                  width: 2,
                ),
              ),
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle_outlined,
                size: 16,
                color: completed ? Colors.white : colors.textMuted,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 36, color: completed ? AppColors.green.withValues(alpha: 0.4) : colors.border),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class KycStatusBadge extends StatelessWidget {
  final String status;

  const KycStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final color = s == 'verified'
        ? AppColors.green
        : s == 'rejected'
            ? AppColors.red
            : AppColors.brandOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.6),
      ),
    );
  }
}

class KycErrorBanner extends StatelessWidget {
  final String message;

  const KycErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
    );
  }
}
