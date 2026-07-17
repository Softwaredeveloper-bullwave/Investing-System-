import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';
import '../constants/dimensions.dart';
import 'premium_ui_kit.dart';
import 'scale_tap.dart';

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      accent: iconColor,
    );
  }
}

class FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  final bool isExpanded;
  final VoidCallback onTap;

  const FaqTile({
    super.key,
    required this.question,
    required this.answer,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.appColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.green,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Text(
                answer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
