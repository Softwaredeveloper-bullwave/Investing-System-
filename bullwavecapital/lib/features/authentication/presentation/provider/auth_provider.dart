import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/api/dev_auth_service.dart';
import '../../../../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  AuthProvider() {
    if (DevConfig.enabled) {
      unawaited(_bootstrapDevSession());
    }
  }

  String _phoneNumber = '';
  bool _termsAccepted = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  UserModel? _user;
  String? _error;
  String? _devOtp;
  String _otpMode = 'console';
  bool _needsEmailVerification = false;
  bool _needsEmailSetup = false;
  String? _existingEmailHint;
  String? _pendingEmail;
  String _emailOtpMode = 'console';
  String? _devEmailOtp;

  String get phoneNumber => _phoneNumber;
  bool get termsAccepted => _termsAccepted;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  UserModel? get user => _user;
  String? get error => _error;
  String? get devOtp => AppEnv.showDevOtpHints ? _devOtp : null;
  bool get otpIsConsoleMode => _otpMode == 'console';

  bool get needsEmailVerification => _needsEmailVerification;
  bool get needsEmailSetup => _needsEmailSetup;

  /// The account's saved email, if any — used to pre-fill the email step
  /// so a returning user doesn't have to retype it every login.
  String? get existingEmailHint => _existingEmailHint;

  /// The email a code was actually sent to (full, unmasked — the user just
  /// typed or confirmed it, so there's no need to hide it from them).
  String? get pendingEmail => _pendingEmail;
  bool get emailOtpIsConsoleMode => _emailOtpMode == 'console';
  String? get devEmailOtp => AppEnv.showDevOtpHints ? _devEmailOtp : null;

  bool get needsProfileSetup =>
      _isAuthenticated && (_user?.hasCompletedOnboarding != true);

  void setPhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    _phoneNumber = digits.length >= 10 ? digits.substring(0, 10) : digits;
  }

  void setTermsAccepted(bool value) {
    _termsAccepted = value;
    notifyListeners();
  }

  void _applyDevSession({UserModel? user}) {
    _isAuthenticated = true;
    _user = user ??
        const UserModel(
          id: 'dev-user',
          name: 'Dev User',
          phone: '9999999999',
          email: 'dev@bullwave.local',
          panStatus: 'Verified',
          kycStatus: 'verified',
          avatarUrl: '',
          hasCompletedOnboarding: true,
        );
    notifyListeners();
  }

  Future<void> _bootstrapDevSession() async {
    _applyDevSession();
    final ok = await DevAuthService.ensureSession(_api);
    if (ok) {
      try {
        _user = await _api.getProfile();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> tryRestoreSession() async {
    if (DevConfig.enabled) {
      await _bootstrapDevSession();
      return true;
    }

    await _api.init();
    try {
      _user = await _api.getProfile();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (_) {
      _isAuthenticated = false;
      _user = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOtp() async {
    if (_phoneNumber.length != 10 || !_termsAccepted) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.sendOtp(_phoneNumber);
      if (AppEnv.blockConsoleOtpInRelease && result.isConsoleMode) {
        _error =
            'Login is temporarily unavailable. Please try again in a few minutes.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _devOtp = result.devOtp;
      _otpMode = result.otpMode;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = AppEnv.isRelease
          ? 'Cannot reach the server. Check your internet connection and try again.'
          : 'Cannot reach server at ${ApiConfig.baseUrl}. Is Django running? (${e.runtimeType})';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// TEMPORARY (testing, 2026-07-18) — logs in with whatever phone number was
  /// set via [setPhoneNumber], skipping OTP entirely, via the backend's
  /// DEBUG-only dev-login endpoint. Used by the login screen when
  /// `DevConfig.skipOtpVerification` is true. Remove/disable alongside that
  /// flag when phone verification should be re-enabled.
  Future<bool> devLoginSkipOtp() async {
    if (_phoneNumber.length != 10 || !_termsAccepted) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.devLogin(phone: _phoneNumber);
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Could not log in. Check your connection and that Django is running.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final code = otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || _phoneNumber.length != 10) {
      _error = _phoneNumber.length != 10
          ? 'Phone number missing. Go back and enter your number again.'
          : 'Enter all 6 digits.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.verifyOtp(_phoneNumber, code);
      if (result.requiresEmailSetup) {
        _needsEmailSetup = true;
        _needsEmailVerification = false;
        _existingEmailHint = result.existingEmail;
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _user = result.user;
      _isAuthenticated = true;
      _needsEmailVerification = false;
      _needsEmailSetup = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e is TimeoutException
          ? 'Server took too long. Check Django is running and try again.'
          : 'Could not verify OTP. Check your connection.';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Step 1.5 — "Send OTP" tap on the email step. Saves the email (typed
  /// fresh, or the pre-filled existing one confirmed as-is) to the account
  /// and sends the code, transitioning into the OTP-entry state.
  Future<bool> submitLoginEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@') || !trimmed.contains('.')) {
      _error = 'Enter a valid email address.';
      notifyListeners();
      return false;
    }
    if (_phoneNumber.length != 10) {
      _error = 'Phone number missing. Go back and enter your number again.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.setLoginEmail(_phoneNumber, trimmed);
      _needsEmailSetup = false;
      _needsEmailVerification = true;
      _pendingEmail = result.email;
      _emailOtpMode = result.otpMode;
      _devEmailOtp = result.devOtp;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e is TimeoutException
          ? 'Server took too long. Check Django is running and try again.'
          : 'Could not send the code. Check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Backs out of OTP entry to let the user fix a typo'd email — purely a
  /// local state reset, no API call (nothing was consumed server-side).
  void backToEmailEntry() {
    _needsEmailVerification = false;
    _needsEmailSetup = true;
    _error = null;
    notifyListeners();
  }

  /// Step 2 — verifies the email OTP sent after phone verification and,
  /// on success, completes login (tokens are issued server-side only now).
  Future<bool> verifyEmailOtp(String otp) async {
    final code = otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || _phoneNumber.length != 10) {
      _error = 'Enter all 6 digits.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.verifyEmailOtp(_phoneNumber, code);
      _isAuthenticated = true;
      _needsEmailVerification = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e is TimeoutException
          ? 'Server took too long. Check Django is running and try again.'
          : 'Could not verify code. Check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendEmailOtp() async {
    if (_phoneNumber.length != 10 || _pendingEmail == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.resendEmailOtp(_phoneNumber, _pendingEmail!);
      _devEmailOtp = result.devOtp;
      _emailOtpMode = result.otpMode;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Could not resend the code. Check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      _user = await _api.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> completeProfileSetup({
    required String name,
    required String email,
    required String city,
    String bio = '',
    DateTime? dateOfBirth,
    String referralCode = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.completeProfileSetup(
        name: name.trim(),
        email: email.trim(),
        city: city.trim(),
        bio: bio.trim(),
        dateOfBirth: dateOfBirth,
        referralCode: referralCode.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to save profile. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String city,
    required String bio,
    DateTime? dateOfBirth,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.updateProfile(
        name: name.trim(),
        email: email.trim(),
        city: city.trim(),
        bio: bio.trim(),
        dateOfBirth: dateOfBirth,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to save profile.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(List<int> bytes, String filename) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.uploadAvatar(bytes, filename);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to upload photo.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    try {
      _user = await _api.removeAvatar();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isAuthenticated = false;
    _user = null;
    _phoneNumber = '';
    _termsAccepted = false;
    _needsEmailVerification = false;
    _needsEmailSetup = false;
    _existingEmailHint = null;
    _pendingEmail = null;
    notifyListeners();
  }
}
