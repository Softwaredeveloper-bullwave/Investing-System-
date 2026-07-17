import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.bottom,
  });

  @override
  Size get preferredSize {
    var height = subtitle != null ? 64.0 : kToolbarHeight;
    if (bottom != null) {
      height += bottom!.preferredSize.height;
    }
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: showBack
          ? IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceSecondary,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : colors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: colors.textPrimary,
                ),
              ),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600),
            ),
        ],
      ),
      centerTitle: true,
      actions: actions,
      bottom: bottom,
    );
  }
}
