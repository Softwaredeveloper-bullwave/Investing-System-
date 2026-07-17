import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/transaction_tile.dart';
import '../../../../models/transaction_model.dart';
import '../provider/transaction_provider.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Transactions'),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: LoadingList(),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by reference or description',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: provider.selectedTab == TransactionType.all,
                      onTap: () => provider.setTab(TransactionType.all),
                    ),
                    _FilterChip(
                      label: 'Investment',
                      selected: provider.selectedTab == TransactionType.investment,
                      onTap: () => provider.setTab(TransactionType.investment),
                    ),
                    _FilterChip(
                      label: 'Profit',
                      selected: provider.selectedTab == TransactionType.profit,
                      onTap: () => provider.setTab(TransactionType.profit),
                    ),
                    _FilterChip(
                      label: 'Withdrawal',
                      selected: provider.selectedTab == TransactionType.withdrawal,
                      onTap: () => provider.setTab(TransactionType.withdrawal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingSm),
              Expanded(
                child: provider.paginatedTransactions.isEmpty
                    ? const Center(child: Text('No transactions found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppDimensions.paddingMd),
                        itemCount: provider.paginatedTransactions.length,
                        itemBuilder: (context, index) => TransactionTile(
                          transaction: provider.paginatedTransactions[index],
                        ),
                      ),
              ),
              _PaginationBar(provider: provider),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final TransactionProvider provider;
  const _PaginationBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: provider.currentPage > 1
                ? () => provider.setPage(provider.currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${provider.currentPage} of ${provider.totalPages}'),
          IconButton(
            onPressed: provider.currentPage < provider.totalPages
                ? () => provider.setPage(provider.currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
