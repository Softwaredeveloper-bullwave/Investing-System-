import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'home_theme_a.dart';

class HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;

  const HomeSearchBar({
    super.key,
    required this.onTap,
    this.hint = 'Search stocks & markets',
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 48,
          decoration: p.cardDecoration(radius: 999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.magnifyingGlass,
                  size: 20,
                  color: p.textGrey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hint,
                    style: ThemeAType.secondary(size: 14, color: p.textGrey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
