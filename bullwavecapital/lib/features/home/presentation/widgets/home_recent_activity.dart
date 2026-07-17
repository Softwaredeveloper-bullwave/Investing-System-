import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/transaction_model.dart';
import 'home_theme_a.dart';

class HomeRecentActivity extends StatelessWidget {
  final List<TransactionModel> transactions;

  const HomeRecentActivity({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Recent Activity',
          actionLabel: transactions.isNotEmpty ? 'View All' : null,
          onAction: transactions.isNotEmpty ? () => context.push(AppRoutes.transactions) : null,
          reserveFabSpace: true,
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: HomeThemeA.cardDecoration(context),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: p.iconCircleDecoration(),
                  child: Icon(
                    PhosphorIcons.receipt,
                    size: 26,
                    color: p.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Activity Yet',
                  style: context.typeSection(16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invest in a featured plan or trade stocks to see transactions here.',
                  textAlign: TextAlign.center,
                  style: context.typeSecondary(14),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.featuredPlansList),
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: p.heroCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: p.primary.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: p.heroCard.withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore Featured Plans',
                            style: ThemeAType.label(size: 13, color: p.heroCardFg),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            PhosphorIcons.arrowRight,
                            size: 14,
                            color: p.heroCardFg,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...transactions.map(
            (txn) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityTile(transaction: txn),
            ),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final TransactionModel transaction;

  const _ActivityTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final p = HomeThemeA.of(context);
    final txn = transaction;
    final isProfit = txn.type == TransactionType.profit;
    final isInvestment = txn.type == TransactionType.investment;
    final accent = isProfit
        ? p.positive
        : isInvestment
            ? p.primary
            : p.textGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: HomeThemeA.cardDecoration(context, shadowTint: accent),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: HomeThemeA.iconCircleDecoration(
              context,
              backgroundColor: accent.withValues(alpha: 0.1),
              borderColor: accent.withValues(alpha: 0.18),
            ),
            child: Icon(
              isProfit
                  ? PhosphorIcons.trendUp
                  : isInvestment
                      ? PhosphorIcons.piggyBank
                      : PhosphorIcons.arrowsLeftRight,
              color: isProfit || isInvestment ? p.primaryDark : p.textGrey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description.isNotEmpty ? txn.description : _labelFor(txn.type),
                  style: ThemeAType.cardTitle(size: 14, color: p.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.display(txn.date),
                  style: ThemeAType.muted(size: 12, color: p.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${isProfit ? '+' : ''}${CurrencyFormatter.format(txn.amount)}',
                    style: ThemeAType.price(
                      size: 15,
                      color: isProfit ? p.positive : p.textDark,
                    ),
                  ),
                ),
                Text(
                  txn.status.name,
                  style: ThemeAType.label(
                    size: 12,
                    color: txn.status == TransactionStatus.completed
                        ? p.positive
                        : p.textGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(TransactionType type) {
    switch (type) {
      case TransactionType.profit:
        return 'Profit credit';
      case TransactionType.investment:
        return 'Investment';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      default:
        return 'Transaction';
    }
  }
}
