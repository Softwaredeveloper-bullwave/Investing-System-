import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await init();
    await _prefs!.setString(_accessKey, access);
    await _prefs!.setString(_refreshKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    await init();
    return _prefs!.getString(_accessKey);
  }

  static Future<void> clear() async {
    await init();
    await _prefs!.remove(_accessKey);
    await _prefs!.remove(_refreshKey);
  }
}
