import 'package:flutter/material.dart';

import '../theme/premium_background.dart';

/// Transparent scaffold on top of the global premium mesh backdrop.
class PremiumScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const PremiumScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

/// Full-screen premium shell when a route is outside [MaterialApp.builder].
class PremiumScreenShell extends StatelessWidget {
  final Widget child;
  final int glowVariant;

  const PremiumScreenShell({
    super.key,
    required this.child,
    this.glowVariant = 0,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumAppBackdrop(
      glowVariant: glowVariant,
      child: child,
    );
  }
}
