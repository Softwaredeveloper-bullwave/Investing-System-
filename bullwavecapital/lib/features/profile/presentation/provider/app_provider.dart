import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  static const _onboardingKey = 'has_completed_app_onboarding';
  static const _darkModeKey = 'is_dark_mode';

  bool _isDarkMode;
  String _language = 'English';
  bool _isLoading = false;
  bool _hasCompletedOnboarding;

  AppProvider._({
    required bool isDarkMode,
    required this._hasCompletedOnboarding,
  }) : _isDarkMode = isDarkMode;

  static Future<AppProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppProvider._(
      // Defaults to the light theme. Users can switch to dark from Settings,
      // and their choice is remembered across app restarts.
      isDarkMode: prefs.getBool(_darkModeKey) ?? false,
      hasCompletedOnboarding: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get isLoading => _isLoading;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  void setLanguage(String value) {
    _language = value;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_hasCompletedOnboarding) return;
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }
}
