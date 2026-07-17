import '../../../../core/api/bullwave_api.dart';
import '../../../../core/config/dev_config.dart';

/// Obtains a real JWT in debug UI mode so market/news/commodity APIs work.
class DevAuthService {
  DevAuthService._();

  static const devPhone = '9999999999';

  static Future<bool> ensureSession(BullwaveApi api) async {
    if (!DevConfig.enabled) return false;

    await api.init();
    try {
      await api.getProfile();
      return true;
    } catch (_) {}

    // Preferred in DEBUG — works even when Twilio SMS is configured.
    try {
      await api.devLogin(phone: devPhone);
      return true;
    } catch (_) {}

    try {
      final sent = await api.sendOtp(devPhone);
      final otp = sent.devOtp;
      if (otp == null || otp.length != 6) return false;
      await api.verifyOtp(devPhone, otp);
      return true;
    } catch (_) {
      return false;
    }
  }
}
