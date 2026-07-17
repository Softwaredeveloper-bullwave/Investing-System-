import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api_config.dart';
import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';

class ModernScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final VoidCallback? onNotificationTap;
  final int notificationCount;
  final Widget? trailing;

  const ModernScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.onNotificationTap,
    this.notificationCount = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedAvatar = ApiConfig.resolveMediaUrl(avatarUrl ?? '');
    final showAvatar = resolvedAvatar.isNotEmpty;

    return Row(
      children: [
        if (showAvatar) ...[
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.brandOrange.withValues(alpha: 0.12),
            backgroundImage: CachedNetworkImageProvider(resolvedAvatar),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (onNotificationTap != null)
          _IconCircleButton(
            icon: Icons.notifications_none_rounded,
            badge: notificationCount,
            onTap: onNotificationTap!,
          ),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : colors.surfaceSecondary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22, color: colors.textPrimary),
              if (badge > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.brandOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
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
}
