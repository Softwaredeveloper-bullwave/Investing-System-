import 'package:flutter/material.dart';

/// Pass-through wrapper — global [PremiumAppBackdrop] in main.dart handles the mesh.
class AppScreenBackground extends StatelessWidget {
  final Widget child;
  final int glowVariant;

  const AppScreenBackground({
    super.key,
    required this.child,
    this.glowVariant = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
