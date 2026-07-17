import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

/// Django backend base URL.
///
/// **Play Store release** (required):
/// ```bash
/// flutter build appbundle --release \
///   --dart-define=API_BASE_URL=https://api.bullwave.in/api/v1
/// ```
///
/// **Local dev — Android emulator:** `10.0.2.2` maps to host machine.
///
/// **Physical phone (same Wi‑Fi):**
/// `flutter run --dart-define=API_HOST=192.168.1.5`
class ApiConfig {
  ApiConfig._();

  static const String _apiBaseFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const String _apiHostFromEnv =
      String.fromEnvironment('API_HOST', defaultValue: '');

  /// Uncomment and set when testing on a real phone on the same Wi‑Fi.
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

    if (kReleaseMode) {
      return _normalizeBase(AppEnv.productionApiBaseUrl);
    }

    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
    return 'http://127.0.0.1:8000/api/v1';
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
    if (kReleaseMode) {
      return Uri.parse(AppEnv.productionApiBaseUrl).host;
    }
    if (kIsWeb) return '127.0.0.1';
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
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
