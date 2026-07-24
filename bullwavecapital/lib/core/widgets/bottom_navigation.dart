import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_a.dart';

/// Forest-Green bottom navigation: four flat tabs (Home / Portfolio /
/// Discover / More) plus a floating circular action button docked in the
/// middle, matching the premium fintech nav-bar mockup.
class AppBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
  });

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  int? _pressedIndex;
  bool _centerPressed = false;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.pie_chart_rounded, 'Portfolio'),
    (Icons.explore_rounded, 'Discover'),
    (Icons.menu_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 66,
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
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        // Leave a gap between Portfolio and Discover for the
                        // floating action button to sit above — every tab
                        // still renders, either side of the gap.
                        if (i == 2) const SizedBox(width: 56),
                        _buildTab(p, i),
                      ],
                    ],
                  ),
                ),
              ),
              // Floating center action button — always solid brand-green
              // with a white icon, so it stays high-contrast and legible
              // regardless of light/dark theme.
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _centerPressed = true),
                  onTapCancel: () => setState(() => _centerPressed = false),
                  onTapUp: (_) => setState(() => _centerPressed = false),
                  onTap: widget.onCenterTap,
                  child: AnimatedScale(
                    scale: _centerPressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    child: Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF16A34A), Color(0xFF083007)],
                        ),
                        border: Border.all(color: p.card, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_vert_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(ThemePalette p, int i) {
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
              child: Icon(
                icon,
                size: active ? 24 : 21,
                // Solid, high-contrast colors only — no light-tint-on-tint
                // combinations that can wash out on some displays.
                color: active ? p.primary : p.textGrey,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: active ? 11.5 : 11,
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
  }
}
