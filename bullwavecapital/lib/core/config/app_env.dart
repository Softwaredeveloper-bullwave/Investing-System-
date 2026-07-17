import 'package:flutter/foundation.dart';

/// Build-time and runtime environment helpers for dev vs Play Store release.
class AppEnv {
  AppEnv._();

  /// `true` for Play Store / profile / release builds.
  static bool get isRelease => kReleaseMode;

  /// Dev UI shortcuts (skip auth, auto-login). Never enabled in release.
  static bool get allowsDevShortcuts => kDebugMode;

  /// Default production API when `--dart-define=API_BASE_URL=...` is omitted.
  /// Deploy Django behind HTTPS at this host before publishing.
  static const String productionApiBaseUrl = 'https://api.bullwave.in/api/v1';

  /// Whether OTP console/dev hints may be shown in the UI.
  static bool get showDevOtpHints => kDebugMode;

  /// Block login when backend returns console OTP mode (SMS not configured).
  static bool get blockConsoleOtpInRelease => kReleaseMode;
}
