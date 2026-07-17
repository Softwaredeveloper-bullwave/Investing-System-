import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../theme/colors.dart';
import '../constants/dimensions.dart';
import '../utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.display(transaction.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Ref: ${transaction.referenceId}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(transaction.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(status: transaction.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _typeColor {
    switch (transaction.type) {
      case TransactionType.investment:
        return AppColors.primary;
      case TransactionType.profit:
        return AppColors.profit;
      case TransactionType.withdrawal:
        return AppColors.warning;
      case TransactionType.all:
        return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (transaction.type) {
      case TransactionType.investment:
        return Icons.savings_outlined;
      case TransactionType.profit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.all:
        return Icons.receipt_long;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final TransactionStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransactionStatus.completed => ('Completed', AppColors.success),
      TransactionStatus.pending => ('Pending', AppColors.warning),
      TransactionStatus.failed => ('Failed', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
