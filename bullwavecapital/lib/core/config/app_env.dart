import 'package:flutter/foundation.dart';

/// Build-time and runtime environment helpers for dev vs Play Store release.
class AppEnv {
  AppEnv._();

  /// `true` for Play Store / profile / release builds.
  static bool get isRelease => kReleaseMode;

  /// Dev UI shortcuts (skip auth, auto-login). Never enabled in release.
  static bool get allowsDevShortcuts => kDebugMode;

  /// Default production API when `--dart-define=API_BASE_URL=...` is omitted.
  /// Currently the AWS EC2-hosted Django backend. Move to a domain name +
  /// HTTPS (e.g. https://api.bullwave.in/api/v1) before publishing to the
  /// Play Store — plain HTTP works for now because cleartext traffic is
  /// allowed in the Android network security config, but it isn't safe for
  /// production traffic (login, OTP, tokens) long-term.
  static const String productionApiBaseUrl = 'http://3.107.192.232/api/v1';

  /// Whether OTP console/dev hints may be shown in the UI.
  static bool get showDevOtpHints => kDebugMode;

  /// Block login when backend returns console OTP mode (SMS not configured).
  static bool get blockConsoleOtpInRelease => kReleaseMode;
}
