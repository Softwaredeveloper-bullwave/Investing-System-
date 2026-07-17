import 'package:flutter/material.dart';

import '../constants/dimensions.dart';
import '../theme/app_decorations.dart';

/// Standard app page — transparent scaffold on top of global premium mesh.
class PremiumPage extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBody;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;

  const PremiumPage({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBody = false,
    this.padding,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = padding != null
        ? Padding(padding: padding!, child: body)
        : body;

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// Premium glass section title — onboarding typography.
class PremiumSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PremiumSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Re-export card styling alias for consistency.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool glow;
  final Color? glowColor;
  final bool premium;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glow = false,
    this.glowColor,
    this.premium = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: AppDecorations.card(
        context,
        glow: glow,
        glowColor: glowColor,
        premium: premium,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
