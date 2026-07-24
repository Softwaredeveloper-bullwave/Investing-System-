import 'package:flutter/material.dart';

import '../theme/theme_a.dart';

/// Premium gradient icon badge used across quick actions and feature tiles.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool large;
  final LinearGradient? gradient;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 22,
    this.large = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dim = large ? 54.0 : 44.0;
    final iconSize = large ? 24.0 : size;

    return Container(
      width: dim,
      height: dim,
      decoration: p.iconCircleDecoration(
        borderColor: color.withValues(alpha: 0.35),
      ),
      child: Icon(icon, color: p.primary, size: iconSize),
    );
  }
}

/// Consistent page header for shell tab screens.
class ShellPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ShellPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ThemeAType.heading(size: 28, color: p.textDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: ThemeAType.secondary(size: 14, color: p.textGrey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(child: trailing!),
        ],
      ],
    );
  }
}
