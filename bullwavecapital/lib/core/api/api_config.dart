import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

/// Django backend base URL.
///
/// Defaults to the deployed AWS backend ([AppEnv.productionApiBaseUrl]) in
/// EVERY build mode (debug, profile, release — including `flutter run -d
/// chrome`), so the app talks to the real server unless you explicitly ask
/// for a local one.
///
/// **Point at a local Django dev server instead:**
/// ```bash
/// flutter run --dart-define=API_HOST=10.0.2.2       # Android emulator
/// flutter run --dart-define=API_HOST=127.0.0.1       # web / iOS sim
/// flutter run --dart-define=API_HOST=192.168.1.5     # physical phone, same Wi‑Fi
/// ```
/// Or set a full custom URL:
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api/v1
/// ```
class ApiConfig {
  ApiConfig._();

  static const String _apiBaseFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const String _apiHostFromEnv =
      String.fromEnvironment('API_HOST', defaultValue: '');

  /// Uncomment and set when testing on a real phone on the same Wi‑Fi,
  /// without passing --dart-define every time.
  static const String? hostOverride = null;

  static String get baseUrl {
    final fromEnv = _normalizeBase(_apiBaseFromEnv.trim());
    if (fromEnv.isNotEmpty) return fromEnv;

    final hostFromDefine = _apiHostFromEnv.trim();
    if (hostFromDefine.isNotEmpty) {
      return _normalizeBase('http://$hostFromDefine:8000/api/v1');
    }

    if (hostOverride != null && hostOverride!.isNotEmpty) {
      return _normalizeBase('http://$hostOverride:8000/api/v1');
    }

    return _normalizeBase(AppEnv.productionApiBaseUrl);
  }

  static String get _apiHost {
    final fromEnv = _apiBaseFromEnv.trim();
    if (fromEnv.isNotEmpty) {
      return Uri.parse(fromEnv).host;
    }
    final hostFromDefine = _apiHostFromEnv.trim();
    if (hostFromDefine.isNotEmpty) {
      return hostFromDefine;
    }
    if (hostOverride != null && hostOverride!.isNotEmpty) {
      return hostOverride!;
    }
    return Uri.parse(AppEnv.productionApiBaseUrl).host;
  }

  static bool get isProductionApi =>
      baseUrl.startsWith('https://') && kReleaseMode;

  /// Rewrites Django media URLs so images load on emulator / physical device.
  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    return uri.replace(host: _apiHost).toString();
  }

  static String _normalizeBase(String url) {
    if (url.isEmpty) return url;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
