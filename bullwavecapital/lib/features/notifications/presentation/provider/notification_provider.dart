import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../models/notification_model.dart';
import '../../../../models/portfolio_rebalance_model.dart';

/// How often to silently check for new notifications in the background.
/// There's no push-notification infra (Firebase/WebSockets) in this app, so
/// this polling is what makes new notifications (e.g. an admin message)
/// show up without the user manually pulling to refresh.
const _kPollInterval = Duration(seconds: 15);

class NotificationProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;
  Timer? _pollTimer;

  bool _isLoading = true;
  bool _isRebalanceChecking = false;
  List<NotificationModel> _notifications = [];
  PortfolioRebalanceModel? _rebalanceStatus;
  String? _rebalanceError;

  bool get isLoading => _isLoading;
  bool get isRebalanceChecking => _isRebalanceChecking;
  List<NotificationModel> get notifications => _notifications;
  PortfolioRebalanceModel? get rebalanceStatus => _rebalanceStatus;
  String? get rebalanceError => _rebalanceError;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  List<NotificationModel> get rebalanceNotifications =>
      _notifications.where((n) => n.type == 'rebalance').toList();

  NotificationProvider() {
    loadData();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollForNew());
  }

  /// Background refresh — deliberately silent (no `_isLoading` flip, so the
  /// list doesn't flash a loading state every 15s) and swallows errors, so a
  /// flaky connection doesn't spam the user; it'll just retry next tick.
  Future<void> _pollForNew() async {
    try {
      final latest = await _api.getNotifications();
      if (_notifications.length != latest.length ||
          (latest.isNotEmpty && (_notifications.isEmpty || latest.first.id != _notifications.first.id))) {
        _notifications = latest;
        notifyListeners();
      }
    } catch (_) {
      // Ignore — next poll will retry.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getNotifications(),
        _api.getPortfolioRebalance(),
      ]);
      _notifications = results[0] as List<NotificationModel>;
      _rebalanceStatus = results[1] as PortfolioRebalanceModel;
      _rebalanceError = null;
    } catch (_) {
      try {
        _notifications = await _api.getNotifications();
      } catch (_) {
        _notifications = [];
      }
      _rebalanceError = 'Could not load AI rebalancing status.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> runRebalanceCheck() async {
    _isRebalanceChecking = true;
    _rebalanceError = null;
    notifyListeners();
    try {
      final result = await _api.runPortfolioRebalanceCheck();
      _rebalanceStatus = result;
      if (result.notificationCreated) {
        _notifications = await _api.getNotifications();
      }
      _isRebalanceChecking = false;
      notifyListeners();
      return result.notificationCreated;
    } catch (_) {
      _rebalanceError = 'AI check failed. Is the backend running?';
      _isRebalanceChecking = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.markNotificationRead(id);
    } catch (_) {}
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {}
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }
}
