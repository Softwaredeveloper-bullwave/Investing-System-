import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/notification_tile.dart';
import '../../../../models/notification_model.dart';
import '../provider/notification_provider.dart';
import '../widgets/ai_rebalance_automation_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _runRebalanceCheck() async {
    final provider = context.read<NotificationProvider>();
    final created = await provider.runRebalanceCheck();
    if (!mounted) return;
    if (created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI rebalancing alert added to your notifications.')),
      );
    } else if (provider.rebalanceError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.rebalanceError!)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portfolio within guardrails — no alert needed.')),
      );
    }
  }

  void _onNotificationTap(BuildContext context, NotificationModel notification) {
    context.read<NotificationProvider>().markAsRead(notification.id);
    if (notification.type == 'rebalance') {
      context.push(AppRoutes.portfolioAnalytics);
    } else if (notification.type == 'alert' || notification.type == 'news') {
      context.push(AppRoutes.priceAlerts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notifications',
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: provider.markAllAsRead,
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: LoadingList(),
            );
          }

          final otherNotifications = provider.notifications
              .where((n) => n.type != 'rebalance')
              .toList();
          final rebalanceNotifications = provider.rebalanceNotifications;

          return RefreshIndicator(
            onRefresh: provider.loadData,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AiRebalanceAutomationCard(
                  status: provider.rebalanceStatus,
                  isChecking: provider.isRebalanceChecking,
                  onRunCheck: _runRebalanceCheck,
                ),
                if (rebalanceNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'Rebalancing alerts',
                      style: ThemeAType.sectionTitle(color: context.palette.textDark, size: 16),
                    ),
                  ),
                  ...rebalanceNotifications.map(
                    (n) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                      child: NotificationTile(
                        notification: n,
                        onTap: () => _onNotificationTap(context, n),
                      ),
                    ),
                  ),
                ],
                if (otherNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      'All notifications',
                      style: ThemeAType.sectionTitle(color: context.palette.textDark, size: 16),
                    ),
                  ),
                  ...otherNotifications.map(
                    (n) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                      child: NotificationTile(
                        notification: n,
                        onTap: () => _onNotificationTap(context, n),
                      ),
                    ),
                  ),
                ],
                if (provider.notifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('No other notifications', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Run an AI check above to monitor portfolio drift.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
