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

  /// TEMPORARY (re-enabled 2026-07-23) — skips the OTP entry screen
  /// entirely. The login screen still takes whatever phone number the user
  /// types, but instead of sending/verifying an OTP it logs straight in via
  /// the backend's DEBUG-only dev-login endpoint and lands on Home.
  ///
  /// Flip back to `false` (or delete this flag) when told to re-enable phone
  /// verification — that single change restores the normal
  /// splash → onboarding → login → OTP → home flow. Has no effect in release
  /// builds (dev-login is DEBUG-only server-side regardless).
  static const bool skipOtpVerification = false;

  /// TEMPORARY (requested 2026-07-22) — removes the PAN verification step
  /// (and the rest of the automated KYC chain: bank + name-match) from the
  /// navigation flow entirely. `KycFlowProvider.isFullyVerified` treats every
  /// user as verified, so the router never redirects into
  /// `AppRoutes.panVerification` and `ensureBankVerified()` (used by Buy/Sell,
  /// wallet, etc.) resolves immediately without pushing any KYC screen.
  ///
  /// The backend mirrors this via `KYC_AUTO_APPROVE` in `.env` (see
  /// `kyc/permissions.py`), so trade/wallet API calls aren't blocked either.
  /// Nothing about the PAN/Eko integration itself was deleted — flip this
  /// back to `false` to restore the full PAN → bank → name-match flow.
  static const bool skipKycVerification = true;
}
