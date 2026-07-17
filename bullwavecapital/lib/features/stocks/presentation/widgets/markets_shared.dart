import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';

class MarketsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MarketsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ThemeAType.sectionTitle(color: p.textDark, size: 20), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: ThemeAType.body(color: p.textGrey, size: 13)),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: ThemeAType.action(color: p.primaryDark)),
            ),
        ],
      ),
    );
  }
}

/// Animated number counter for portfolio metrics.
class AnimatedMetricText extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String Function(double) formatter;
  final Duration duration;

  const AnimatedMetricText({
    super.key,
    required this.value,
    required this.style,
    required this.formatter,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(formatter(v), style: style),
    );
  }
}

bool isIndianMarketOpen([DateTime? now]) {
  final ist = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
  if (ist.weekday == DateTime.saturday || ist.weekday == DateTime.sunday) return false;
  final minutes = ist.hour * 60 + ist.minute;
  return minutes >= 9 * 60 + 15 && minutes <= 15 * 60 + 30;
}
