import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'home_theme_a.dart';

class HomeActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HomeActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Primary Invest / SIP / Add Money / Scan & Pay row — white pill card with
/// four evenly spaced icon+label actions, matching the Forest Green mockup.
class HomeActionRow extends StatelessWidget {
  final List<HomeActionItem> actions;

  const HomeActionRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: p.cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final action in actions)
            Expanded(
              child: ScaleTap(
                onTap: action.onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.green, AppColors.brandPrimary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      // Solid brand-green circle + white icon: guaranteed
                      // contrast regardless of light/dark theme, and no
                      // reliance on faint tint-on-tint combinations.
                      child: Icon(action.icon, size: 21, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      style: ThemeAType.label(size: 12, color: p.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
