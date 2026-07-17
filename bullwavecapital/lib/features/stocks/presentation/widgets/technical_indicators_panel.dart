import 'package:flutter/material.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../models/stock_model.dart';

class TechnicalIndicatorsPanel extends StatelessWidget {
  final TechnicalIndicatorsModel indicators;

  const TechnicalIndicatorsPanel({super.key, required this.indicators});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Technical Indicators',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'RSI', value: indicators.rsi.toStringAsFixed(1), color: _rsiColor(indicators.rsi)),
              _Chip(label: 'MACD', value: indicators.macdSignal, color: AppColors.blue),
              _Chip(label: 'SMA 50', value: '₹${indicators.sma50.toStringAsFixed(0)}', color: colors.textSecondary),
              _Chip(label: 'SMA 200', value: '₹${indicators.sma200.toStringAsFixed(0)}', color: colors.textSecondary),
              _Chip(
                label: 'Trend',
                value: indicators.trend,
                color: indicators.trend == 'Uptrend' || indicators.trend == 'Bullish'
                    ? AppColors.green
                    : indicators.trend == 'Downtrend' || indicators.trend == 'Bearish'
                        ? AppColors.red
                        : AppColors.yellow,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _rsiColor(double rsi) {
    if (rsi > 70) return AppColors.red;
    if (rsi < 30) return AppColors.green;
    return AppColors.blue;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

class MarketsFeatureGrid extends StatelessWidget {
  final List<({IconData icon, String label, Color color, VoidCallback onTap})> items;

  const MarketsFeatureGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: items.map((item) {
        return Material(
          color: context.appColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AppDecorations.iconBadge(item.color),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
