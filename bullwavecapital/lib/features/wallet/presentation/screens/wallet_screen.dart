import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/kyc_completion_banner.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../provider/wallet_provider.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: LoadingList(itemCount: 3),
            ),
          );
        }

        final wallet = provider.wallet;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShellPageHeader(
                  title: 'Wallet',
                  subtitle: 'Manage balance, deposits & withdrawals',
                ),
                const SizedBox(height: 12),
                const KycCompletionBanner(),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AppDecorations.heroCard(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Balance',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.appColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      MoneyText(amount: CurrencyFormatter.format(wallet.balance), fontSize: 38),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Add Money',
                              icon: Icons.add_rounded,
                              compact: true,
                              onPressed: () async {
                                if (!await ensureBankVerified(context)) return;
                                if (context.mounted) context.push(AppRoutes.deposit);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SecondaryButton(
                              label: 'Withdraw',
                              icon: Icons.arrow_upward_rounded,
                              compact: true,
                              onPressed: () async {
                                if (!await ensureBankVerified(context)) return;
                                if (context.mounted) context.push(AppRoutes.withdraw);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(title: 'Bank Account'),
                const SizedBox(height: AppDimensions.paddingSm),
                RobinhoodCard(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance, color: AppColors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(wallet.bankName, style: Theme.of(context).textTheme.titleMedium),
                            Text('A/C ${wallet.accountNumber} • ${wallet.ifsc}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified, color: AppColors.green, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingLg),
                SectionHeader(
                  title: 'Transactions',
                  actionLabel: 'View All',
                  onAction: () => context.push(AppRoutes.transactions),
                ),
                const SizedBox(height: AppDimensions.paddingSm),
                ...provider.transactions.map((txn) {
                  final isCredit = txn.type != 'Withdrawal';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RobinhoodCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${isCredit ? '+' : '-'} ${CurrencyFormatter.format(txn.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isCredit ? AppColors.green : AppColors.red,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  txn.type,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  DateFormatter.display(txn.date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              txn.status,
                              style: TextStyle(
                                color: txn.status == 'Completed' ? AppColors.green : AppColors.yellow,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: ShellLayout.contentBottomInset),
              ],
            ),
          ),
        );
      },
    );
  }
}
