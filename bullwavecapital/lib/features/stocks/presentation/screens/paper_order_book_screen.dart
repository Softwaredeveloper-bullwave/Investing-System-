import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/paper_trading_model.dart';
import '../provider/paper_trading_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import '../widgets/simulation_badge.dart';

/// Paper order book — every order ever placed (pending/executed/cancelled/
/// rejected), with modify + cancel for anything still PENDING.
class PaperOrderBookScreen extends StatefulWidget {
  const PaperOrderBookScreen({super.key});

  @override
  State<PaperOrderBookScreen> createState() => _PaperOrderBookScreenState();
}

class _PaperOrderBookScreenState extends State<PaperOrderBookScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<PaperTradingProvider>().loadOrderBook(status: _statusFilter);
  }

  Future<void> _cancel(PaperOrderModel order) async {
    final ok = await context.read<PaperTradingProvider>().cancelOrder(order.id);
    if (!mounted) return;
    if (ok) {
      await context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Order cancelled.' : 'Could not cancel order.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _modify(PaperOrderModel order) async {
    final qtyController = TextEditingController(text: '${order.quantity}');
    final priceController = TextEditingController(
      text: (order.limitPrice ?? order.triggerPrice ?? 0).toStringAsFixed(2),
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modify order — ${order.symbol}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            ),
            if (order.limitPrice != null || order.triggerPrice != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: order.limitPrice != null ? 'Limit price' : 'Trigger price',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;

    final qty = int.tryParse(qtyController.text.trim());
    final price = double.tryParse(priceController.text.trim());
    final ok = await context.read<PaperTradingProvider>().modifyOrder(
          order.id,
          quantity: qty,
          limitPrice: order.limitPrice != null ? price : null,
          triggerPrice: order.triggerPrice != null ? price : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Order updated.' : 'Could not modify order.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Paper Order Book'),
      body: Consumer<PaperTradingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingOrderBook && provider.orderBook.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 5, itemHeight: 76),
            );
          }
          final orders = provider.orderBook;
          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: SimulationOnlyBadge(compact: true)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in [null, 'PENDING', 'EXECUTED', 'CANCELLED', 'REJECTED'])
                      ChoiceChip(
                        label: Text(s ?? 'All'),
                        selected: _statusFilter == s,
                        onSelected: (_) {
                          setState(() => _statusFilter = s);
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (orders.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: AppDecorations.card(context),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 40, color: colors.textMuted),
                        const SizedBox(height: 10),
                        Text('No orders yet', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else
                  ...orders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OrderRow(order: o, onModify: () => _modify(o), onCancel: () => _cancel(o)),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final PaperOrderModel order;
  final VoidCallback onModify;
  final VoidCallback onCancel;

  const _OrderRow({required this.order, required this.onModify, required this.onCancel});

  Color _statusColor() {
    switch (order.status) {
      case 'EXECUTED':
        return AppColors.green;
      case 'PENDING':
        return AppColors.brandOrange;
      case 'REJECTED':
        return AppColors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sideColor = order.isBuy ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(order.side, style: TextStyle(color: sideColor, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(order.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor().withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(order.status, style: TextStyle(color: _statusColor(), fontWeight: FontWeight.w800, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.orderType} · Qty ${order.quantity}'
            '${order.limitPrice != null ? ' · Limit ${CurrencyFormatter.format(order.limitPrice!)}' : ''}'
            '${order.triggerPrice != null ? ' · Trigger ${CurrencyFormatter.format(order.triggerPrice!)}' : ''}'
            '${order.executedPrice != null ? ' · Filled ${CurrencyFormatter.format(order.executedPrice!)}' : ''}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          if (order.rejectReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(order.rejectReason, style: TextStyle(color: AppColors.red, fontSize: 11)),
          ],
          if (order.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onModify,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    child: const Text('Modify', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
