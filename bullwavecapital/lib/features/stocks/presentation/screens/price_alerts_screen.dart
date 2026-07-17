import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/portfolio_health_model.dart';
import '../../../../models/stock_model.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _symbolController = TextEditingController(text: 'RELIANCE');
  final _priceController = TextEditingController(text: '1500');
  final _keywordController = TextEditingController();
  String _condition = 'above';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _symbolController.dispose();
    _priceController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<StockFeaturesProvider>().refreshAlerts();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createPriceAlert() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (symbol.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid symbol and target price')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await context.read<StockFeaturesProvider>().addAlert(
          symbol: symbol,
          targetPrice: price,
          condition: _condition,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Price alert created for $symbol' : 'Failed to create alert'),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ),
    );
  }

  Future<void> _createNewsAlert() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a symbol or keyword (e.g. RELIANCE, RBI)')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final ok = await context.read<StockFeaturesProvider>().addNewsAlert(keyword);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) _keywordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'News alert created for $keyword' : 'Failed to create news alert'),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Alerts',
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.brandPrimary,
          unselectedLabelColor: colors.textMuted,
          indicatorColor: AppColors.brandPrimary,
          tabs: const [
            Tab(text: 'Price Alerts'),
            Tab(text: 'News Alerts'),
          ],
        ),
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: LoadingList(itemCount: 4, itemHeight: 72),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                RefreshIndicator(
                  color: AppColors.brandOrange,
                  onRefresh: _load,
                  child: Consumer2<StockFeaturesProvider, StockMarketProvider>(
                    builder: (context, features, market, _) {
                      final alerts = features.alerts;
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _CreatePriceAlertCard(
                            colors: colors,
                            symbolController: _symbolController,
                            priceController: _priceController,
                            condition: _condition,
                            isSaving: _isSaving,
                            suggestions: market.trendingStocks.take(5).map((s) => s.symbol).toList(),
                            onConditionChanged: (v) => setState(() => _condition = v),
                            onCreate: _createPriceAlert,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your Price Alerts (${alerts.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (alerts.isEmpty)
                            _EmptyState(
                              colors: colors,
                              icon: Icons.notifications_active_outlined,
                              title: 'No price alerts yet',
                              subtitle: 'Get notified when a stock hits your target price.',
                            )
                          else
                            ...alerts.map(
                              (a) => _PriceAlertCard(
                                alert: a,
                                colors: colors,
                                onToggle: () => features.toggleAlert(a.id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                RefreshIndicator(
                  color: AppColors.brandOrange,
                  onRefresh: _load,
                  child: Consumer2<StockFeaturesProvider, StockMarketProvider>(
                    builder: (context, features, market, _) {
                      final alerts = features.newsAlerts;
                      final suggestions = [
                        ...market.trendingStocks.take(4).map((s) => s.symbol),
                        'RBI',
                        'NIFTY',
                        'IPO',
                      ];
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _CreateNewsAlertCard(
                            colors: colors,
                            keywordController: _keywordController,
                            isSaving: _isSaving,
                            suggestions: suggestions,
                            onCreate: _createNewsAlert,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your News Alerts (${alerts.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (alerts.isEmpty)
                            _EmptyState(
                              colors: colors,
                              icon: Icons.newspaper_outlined,
                              title: 'No news alerts yet',
                              subtitle: 'Watch a symbol or keyword — we notify you when matching headlines appear.',
                            )
                          else
                            ...alerts.map(
                              (a) => _NewsAlertCard(
                                alert: a,
                                colors: colors,
                                onToggle: () => features.toggleNewsAlert(a.id),
                                onDelete: () => features.deleteNewsAlert(a.id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _CreatePriceAlertCard extends StatelessWidget {
  final AppThemeExtension colors;
  final TextEditingController symbolController;
  final TextEditingController priceController;
  final String condition;
  final bool isSaving;
  final List<String> suggestions;
  final ValueChanged<String> onConditionChanged;
  final VoidCallback onCreate;

  const _CreatePriceAlertCard({
    required this.colors,
    required this.symbolController,
    required this.priceController,
    required this.condition,
    required this.isSaving,
    required this.suggestions,
    required this.onConditionChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Price Alert', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: symbolController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Symbol',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                onPressed: () => symbolController.text = s,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target price (₹)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Above'),
                  selected: condition == 'above',
                  onSelected: (_) => onConditionChanged('above'),
                  selectedColor: AppColors.green.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Below'),
                  selected: condition == 'below',
                  onSelected: (_) => onConditionChanged('below'),
                  selectedColor: AppColors.red.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onCreate,
              icon: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_alert_rounded),
              label: const Text('Create Price Alert', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateNewsAlertCard extends StatelessWidget {
  final AppThemeExtension colors;
  final TextEditingController keywordController;
  final bool isSaving;
  final List<String> suggestions;
  final VoidCallback onCreate;

  const _CreateNewsAlertCard({
    required this.colors,
    required this.keywordController,
    required this.isSaving,
    required this.suggestions,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New News Alert', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Get notified when headlines mention your keyword or stock.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: keywordController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Keyword / Symbol',
              hintText: 'RELIANCE, RBI, IPO…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                onPressed: () => keywordController.text = s,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onCreate,
              icon: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.newspaper_rounded),
              label: const Text('Create News Alert', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceAlertCard extends StatelessWidget {
  final PriceAlertModel alert;
  final AppThemeExtension colors;
  final VoidCallback onToggle;

  const _PriceAlertCard({required this.alert, required this.colors, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isAbove = alert.condition.toLowerCase() == 'above';
    final accent = isAbove ? AppColors.green : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: AppDecorations.iconBadge(accent),
            child: Icon(Icons.notifications_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(alert.name, style: TextStyle(color: colors.textMuted, fontSize: 12)),
                Text(
                  '${isAbove ? 'Above' : 'Below'} ${CurrencyFormatter.formatDecimal(alert.targetPrice)}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(value: alert.isActive, activeThumbColor: AppColors.green, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

class _NewsAlertCard extends StatelessWidget {
  final NewsAlertModel alert;
  final AppThemeExtension colors;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _NewsAlertCard({
    required this.alert,
    required this.colors,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: AppDecorations.iconBadge(AppColors.brandPrimary),
            child: const Icon(Icons.newspaper_rounded, color: AppColors.brandPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.keyword, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (alert.lastMatchedTitle.isNotEmpty)
                  Text(
                    'Last: ${alert.lastMatchedTitle}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  )
                else
                  Text('Watching market headlines…', style: TextStyle(color: colors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: alert.isActive, activeThumbColor: AppColors.green, onChanged: (_) => onToggle()),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppThemeExtension colors;
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          Icon(icon, size: 44, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colors.textSecondary)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
