import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';

class InvestmentCalculatorScreen extends StatefulWidget {
  const InvestmentCalculatorScreen({super.key});

  @override
  State<InvestmentCalculatorScreen> createState() => _InvestmentCalculatorScreenState();
}

class _InvestmentCalculatorScreenState extends State<InvestmentCalculatorScreen> {
  double _monthly = 5000;
  double _rate = 12;
  int _years = 10;

  double get _invested => _monthly * 12 * _years;

  double get _futureValue {
    final r = _rate / 12 / 100;
    final n = _years * 12;
    if (r == 0) return _invested;
    return _monthly * ((math.pow(1 + r, n) - 1) / r) * (1 + r);
  }

  double get _gains => _futureValue - _invested;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Investment Calculator'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIP Calculator', style: ThemeAType.sectionTitle(color: p.textDark, size: 20)),
                const SizedBox(height: 6),
                Text(
                  'Estimate wealth from monthly SIP — for planning only.',
                  style: ThemeAType.body(color: p.textGrey, size: 13),
                ),
                const SizedBox(height: 24),
                _SliderField(
                  label: 'Monthly investment',
                  value: _monthly,
                  min: 500,
                  max: 100000,
                  divisions: 40,
                  display: CurrencyFormatter.formatCompact(_monthly),
                  onChanged: (v) => setState(() => _monthly = v),
                ),
                _SliderField(
                  label: 'Expected return (p.a.)',
                  value: _rate,
                  min: 4,
                  max: 24,
                  divisions: 20,
                  display: '${_rate.toStringAsFixed(1)}%',
                  onChanged: (v) => setState(() => _rate = v),
                ),
                _SliderField(
                  label: 'Time period',
                  value: _years.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  display: '${_years.round()} years',
                  onChanged: (v) => setState(() => _years = v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            glow: true,
            glowColor: p.primary.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Projected outcome', style: ThemeAType.sectionTitle(color: p.textDark, size: 18)),
                const SizedBox(height: 16),
                _ResultRow(label: 'Total invested', value: CurrencyFormatter.format(_invested)),
                const SizedBox(height: 10),
                _ResultRow(label: 'Est. returns', value: CurrencyFormatter.format(_gains), highlight: true),
                const SizedBox(height: 10),
                _ResultRow(
                  label: 'Future value',
                  value: CurrencyFormatter.format(_futureValue),
                  isLarge: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: ThemeAType.body(color: p.textGrey, size: 14)),
              const Spacer(),
              Text(display, style: ThemeAType.cardTitle(color: p.primary, size: 15)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: p.primary,
              inactiveTrackColor: p.borderLight,
              thumbColor: p.primary,
              overlayColor: p.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool isLarge;

  const _ResultRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(child: Text(label, style: ThemeAType.body(color: p.textGrey, size: 14))),
        Text(
          value,
          style: isLarge
              ? ThemeAType.sectionTitle(color: p.textDark, size: 22)
              : ThemeAType.cardTitle(
                  color: highlight ? p.positive : p.textDark,
                  size: 16,
                ),
        ),
      ],
    );
  }
}