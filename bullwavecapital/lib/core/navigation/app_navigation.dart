import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safe navigation helpers for GoRouter + ShellRoute.
class AppNavigation {
  AppNavigation._();

  /// Switch to a main tab / shell route — never use [push] for these.
  static void goTab(BuildContext context, String route) {
    GoRouter.of(context).go(route);
  }

  /// Pop overlay routes (bottom sheets, dialogs) then go to a shell tab.
  static void closeOverlaysAndGoTab(BuildContext context, String route) {
    final router = GoRouter.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    while (rootNav.canPop()) {
      rootNav.pop();
    }
    router.go(route);
  }

  static Future<T?> showAppBottomSheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }
}
