import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'home_theme_a.dart';

class HomeCleanHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  const HomeCleanHeader({
    super.key,
    this.onMenuTap,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        _HeaderIconButton(
          icon: PhosphorIcons.list,
          onTap: onMenuTap,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'BullWave',
                textAlign: TextAlign.center,
                style: ThemeAType.heading(size: 22, color: p.textDark),
              ),
              const SizedBox(height: 2),
              Text(
                'Invest',
                style: ThemeAType.label(size: 12, color: p.textGrey)
                    .copyWith(letterSpacing: 2.0, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _HeaderIconButton(
              icon: PhosphorIcons.bell,
              onTap: onNotificationTap,
            ),
            if (notificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: ThemeAType.label(size: 10, color: p.onPrimary).copyWith(height: 1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: p.cardDecoration(radius: 20),
          child: Icon(icon, size: 20, color: p.textDark),
        ),
      ),
    );
  }
}
