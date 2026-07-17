import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/scale_tap.dart';

class HomeQuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const HomeQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class HomePrimaryActionsRow extends StatelessWidget {
  final List<HomeQuickAction> actions;

  const HomePrimaryActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _PrimaryActionTile(action: actions[i])),
        ],
      ],
    );
  }
}

class _PrimaryActionTile extends StatelessWidget {
  final HomeQuickAction action;

  const _PrimaryActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ScaleTap(
      onTap: action.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: p.iconCircleDecoration(),
            child: Icon(action.icon, size: 22, color: p.primaryDark),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            style: context.typeLabel(13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class HomeSecondaryActionsRow extends StatelessWidget {
  final List<HomeQuickAction> actions;

  const HomeSecondaryActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _SecondaryActionTile(action: actions[i])),
        ],
      ],
    );
  }
}

class _SecondaryActionTile extends StatelessWidget {
  final HomeQuickAction action;

  const _SecondaryActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ScaleTap(
      onTap: action.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: p.cardDecoration(radius: 23),
            child: Icon(action.icon, size: 20, color: p.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            style: context.typeLabel(12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
