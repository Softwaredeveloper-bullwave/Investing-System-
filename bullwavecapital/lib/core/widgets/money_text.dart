import 'package:flutter/material.dart';
import '../theme/theme_a.dart';
import '../theme/typography.dart';
import '../theme/app_theme_extension.dart';

class MoneyText extends StatelessWidget {
  final String amount;
  final double? fontSize;
  final Color? color;
  final TextAlign align;

  const MoneyText({
    super.key,
    required this.amount,
    this.fontSize,
    this.color,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      amount,
      textAlign: align,
      style: AppTypography.balance(colors, color: color).copyWith(fontSize: fontSize),
    );
  }
}

class ProfitChangeText extends StatelessWidget {
  final double amount;
  final String? prefix;
  final bool showSign;

  const ProfitChangeText({
    super.key,
    required this.amount,
    this.prefix,
    this.showSign = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    final sign = showSign ? (isPositive ? '+' : '') : '';
    final label = prefix != null ? '$prefix ' : '';
    return Text(
      '$label$sign${_formatAmount(amount.abs())}',
      style: AppTypography.profitChange(isPositive: isPositive),
    );
  }

  String _formatAmount(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    return '₹${v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        )}';
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTypography.sectionTitle(colors)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionLabel!,
                style: ThemeAType.action(size: 13, color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
