import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';

class OptionStrikeRow {
  final double strike;
  final OptionContractModel? call;
  final OptionContractModel? put;

  const OptionStrikeRow({required this.strike, this.call, this.put});
}

List<OptionStrikeRow> mergeOptionChain(List<OptionContractModel> contracts) {
  final byStrike = <double, OptionStrikeRow>{};
  for (final c in contracts) {
    final existing = byStrike[c.strike];
    if (c.type == 'CE') {
      byStrike[c.strike] = OptionStrikeRow(
        strike: c.strike,
        call: c,
        put: existing?.put,
      );
    } else {
      byStrike[c.strike] = OptionStrikeRow(
        strike: c.strike,
        call: existing?.call,
        put: c,
      );
    }
  }
  final rows = byStrike.values.toList()..sort((a, b) => a.strike.compareTo(b.strike));
  return rows;
}

class OptionChainTable extends StatelessWidget {
  final List<OptionContractModel> contracts;
  final double spot;
  final int strikeDecimals;
  final String currencySymbol;
  final void Function(OptionContractModel contract)? onContractTap;

  const OptionChainTable({
    super.key,
    required this.contracts,
    required this.spot,
    this.strikeDecimals = 0,
    this.currencySymbol = '',
    this.onContractTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rows = mergeOptionChain(contracts);
    if (rows.isEmpty) {
      return const Center(child: Text('No contracts'));
    }

    final maxCallOi = rows.map((r) => r.call?.oi ?? 0).fold(0, (a, b) => a > b ? a : b);
    final maxPutOi = rows.map((r) => r.put?.oi ?? 0).fold(0, (a, b) => a > b ? a : b);
    final step = _strikeStep(spot);

    return Column(
      children: [
        _TableHeader(colors: colors),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              final isAtm = (row.strike - spot).abs() <= step / 2;
              return _StrikeRow(
                row: row,
                spot: spot,
                isAtm: isAtm,
                maxCallOi: maxCallOi,
                maxPutOi: maxPutOi,
                colors: colors,
                strikeDecimals: strikeDecimals,
                currencySymbol: currencySymbol,
                onContractTap: onContractTap,
              );
            },
          ),
        ),
      ],
    );
  }

  double _strikeStep(double spot) {
    if (spot >= 5000) return 100;
    if (spot >= 2000) return 50;
    if (spot >= 1000) return 20;
    if (spot >= 500) return 10;
    return 5;
  }
}

class _TableHeader extends StatelessWidget {
  final AppThemeExtension colors;

  const _TableHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _HeaderCell(label: 'OI', sub: 'Call', flex: 2, align: TextAlign.end, colors: colors),
          _HeaderCell(label: 'LTP', sub: 'CE', flex: 2, align: TextAlign.end, colors: colors, color: AppColors.green),
          _HeaderCell(label: 'STRIKE', flex: 3, align: TextAlign.center, colors: colors, bold: true),
          _HeaderCell(label: 'LTP', sub: 'PE', flex: 2, align: TextAlign.start, colors: colors, color: AppColors.red),
          _HeaderCell(label: 'OI', sub: 'Put', flex: 2, align: TextAlign.start, colors: colors),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final String? sub;
  final int flex;
  final TextAlign align;
  final AppThemeExtension colors;
  final Color? color;
  final bool bold;

  const _HeaderCell({
    required this.label,
    this.sub,
    required this.flex,
    required this.align,
    required this.colors,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: align,
            style: TextStyle(
              fontSize: 10,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              textAlign: align,
              style: TextStyle(fontSize: 8, color: colors.textMuted, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

class _StrikeRow extends StatelessWidget {
  final OptionStrikeRow row;
  final double spot;
  final bool isAtm;
  final int maxCallOi;
  final int maxPutOi;
  final AppThemeExtension colors;
  final int strikeDecimals;
  final String currencySymbol;
  final void Function(OptionContractModel contract)? onContractTap;

  const _StrikeRow({
    required this.row,
    required this.spot,
    required this.isAtm,
    required this.maxCallOi,
    required this.maxPutOi,
    required this.colors,
    this.strikeDecimals = 0,
    this.currencySymbol = '',
    this.onContractTap,
  });

  @override
  Widget build(BuildContext context) {
    final call = row.call;
    final put = row.put;
    final bg = isAtm
        ? AppColors.brandOrange.withValues(alpha: 0.08)
        : row.strike < spot
            ? AppColors.green.withValues(alpha: 0.03)
            : AppColors.red.withValues(alpha: 0.03);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
          left: isAtm
              ? BorderSide(color: AppColors.brandOrange, width: 3)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _OiCell(oi: call?.oi ?? 0, maxOi: maxCallOi, align: TextAlign.end, colors: colors),
          _LtpCell(
            contract: call,
            isCall: true,
            colors: colors,
            currencySymbol: currencySymbol,
            onTap: call != null && onContractTap != null ? () => onContractTap!(call) : null,
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  row.strike.toStringAsFixed(strikeDecimals),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isAtm ? AppColors.brandOrange : colors.textPrimary,
                  ),
                ),
                if (isAtm)
                  Text(
                    'ATM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandOrange,
                    ),
                  ),
              ],
            ),
          ),
          _LtpCell(
            contract: put,
            isCall: false,
            colors: colors,
            currencySymbol: currencySymbol,
            onTap: put != null && onContractTap != null ? () => onContractTap!(put) : null,
          ),
          _OiCell(oi: put?.oi ?? 0, maxOi: maxPutOi, align: TextAlign.start, colors: colors),
        ],
      ),
    );
  }
}

class _LtpCell extends StatelessWidget {
  final OptionContractModel? contract;
  final bool isCall;
  final AppThemeExtension colors;
  final String currencySymbol;
  final VoidCallback? onTap;

  const _LtpCell({
    required this.contract,
    required this.isCall,
    required this.colors,
    this.currencySymbol = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (contract == null) {
      return Expanded(flex: 2, child: Text('—', textAlign: isCall ? TextAlign.end : TextAlign.start));
    }
    final c = contract!;
    final changeColor = c.change >= 0 ? AppColors.green : AppColors.red;

    final content = Column(
      crossAxisAlignment: isCall ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          '$currencySymbol${c.ltp.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: isCall ? AppColors.green : AppColors.red,
          ),
        ),
        Text(
          '${c.change >= 0 ? '+' : ''}${c.change.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 10, color: changeColor, fontWeight: FontWeight.w600),
        ),
      ],
    );

    return Expanded(
      flex: 2,
      child: onTap == null
          ? content
          : Material(
              color: (isCall ? AppColors.green : AppColors.red).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _OiCell extends StatelessWidget {
  final int oi;
  final int maxOi;
  final TextAlign align;
  final AppThemeExtension colors;

  const _OiCell({
    required this.oi,
    required this.maxOi,
    required this.align,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxOi > 0 ? oi / maxOi : 0.0;
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment:
            align == TextAlign.end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            _formatOi(oi),
            textAlign: align,
            style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 36,
            height: 3,
            child: Align(
              alignment: align == TextAlign.end ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.08, 1.0),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatOi(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class OptionChainSummary extends StatelessWidget {
  final double spot;
  final List<OptionContractModel> contracts;
  final String symbol;

  const OptionChainSummary({
    super.key,
    required this.spot,
    required this.contracts,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final calls = contracts.where((c) => c.type == 'CE');
    final puts = contracts.where((c) => c.type == 'PE');
    final callOi = calls.fold(0, (sum, c) => sum + c.oi);
    final putOi = puts.fold(0, (sum, c) => sum + c.oi);
    final pcr = callOi > 0 ? putOi / callOi : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandOrange.withValues(alpha: 0.12),
            colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                symbol.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            IndexFormatter.format(spot),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricChip(label: 'PCR', value: pcr.toStringAsFixed(2), colors: colors),
              const SizedBox(width: 8),
              _MetricChip(label: 'Call OI', value: _formatOi(callOi), colors: colors),
              const SizedBox(width: 8),
              _MetricChip(label: 'Put OI', value: _formatOi(putOi), colors: colors),
            ],
          ),
        ],
      ),
    );
  }

  String _formatOi(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;

  const _MetricChip({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: colors.textMuted, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
