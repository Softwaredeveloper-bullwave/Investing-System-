import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/theme_a.dart';

class AppBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  int? _pressedIndex;

  static const _items = [
    (PhosphorIcons.house, 'Home'),
    (PhosphorIcons.chartLineUp, 'Markets'),
    (PhosphorIcons.chartPie, 'Portfolio'),
    (PhosphorIcons.wallet, 'Wallet'),
    (PhosphorIcons.user, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.borderLight),
            boxShadow: p.isDark
                ? [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF0A0A0A).withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final (icon, label) = _items[i];
              final active = i == widget.currentIndex;
              final pressed = _pressedIndex == i;

              return Expanded(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressedIndex = i),
                  onTapCancel: () => setState(() => _pressedIndex = null),
                  onTapUp: (_) => setState(() => _pressedIndex = null),
                  onTap: () => widget.onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 1,
                          end: active ? 1.08 : (pressed ? 0.92 : 1.0),
                        ),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: active ? 44 : 38,
                          height: active ? 44 : 38,
                          decoration: active
                              ? BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      p.primarySoft,
                                      p.primary.withValues(alpha: p.isDark ? 0.35 : 0.55),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.primaryBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.primary.withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                )
                              : null,
                          child: Icon(
                            icon,
                            size: active ? 23 : 20,
                            color: active ? p.primaryDark : p.textGrey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: GoogleFonts.inter(
                          fontSize: active ? 12 : 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? p.textDark : p.textGrey,
                          height: 1.1,
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
