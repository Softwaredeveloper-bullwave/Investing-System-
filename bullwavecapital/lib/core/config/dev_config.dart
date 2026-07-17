import 'package:flutter/foundation.dart';

/// Development shortcuts for UI work.
///
/// Set [skipToHomeForUiEditing] to `true` only when editing home UI without auth.
/// Normal flow: splash → onboarding → login → OTP → home.
class DevConfig {
  DevConfig._();

  /// Opens home immediately and bypasses auth + KYC gates (debug builds only).
  static const bool skipToHomeForUiEditing = false;

  static bool get enabled => kDebugMode && skipToHomeForUiEditing;
}
