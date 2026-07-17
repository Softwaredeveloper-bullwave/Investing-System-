import 'package:flutter/material.dart';

import '../../../../core/widgets/premium_ui_kit.dart';

class HomePromoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const HomePromoBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return AiInsightCard(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
