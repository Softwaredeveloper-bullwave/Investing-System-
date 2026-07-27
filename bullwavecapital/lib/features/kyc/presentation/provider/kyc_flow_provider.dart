import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/dev_config.dart';
import '../../../../core/api/api_exception.dart';

import '../../data/kyc_repository.dart';

import '../../domain/kyc_models.dart';

import '../../models/kyc_status_model.dart';

import '../../services/kyc_api_service.dart';



class KycFlowProvider extends ChangeNotifier {

  final _kycRepo = KycRepository();

  final _manualApi = KycApiService.instance;

  final _paymentRepo = PaymentRepository();



  KycStatusModel status = KycStatusModel.empty;

  ManualKycStatusModel manualStatus = ManualKycStatusModel.empty;

  bool isLoading = false;

  bool statusLoaded = false;

  String? error;

  /// Number of KYC wizard screens (PAN → bank → name-match, or the status
  /// dashboard) currently pushed on top of whatever screen triggered the
  /// flow — a Buy button, a wallet action, the home banner, Profile, etc.
  /// Each screen increments this right before pushing the next step; once
  /// verification finishes, `finishKycFlow()` (bank_verification_guard.dart)
  /// pops exactly this many times to land back on that original screen with
  /// its context and in-progress action still intact, then resets it to 0.
  int kycPushDepth = 0;



  /// Manual admin-reviewed KYC (legacy — kept for old submissions, no longer the primary path).

  bool get isManualKycVerified => manualStatus.isVerified;

  /// Automated PAN (Eko) + bank + name-match flow — the primary KYC path.
  bool get isAutomatedKycVerified => status.isFullyVerified;

  /// Markets & trading access.

  bool get isFullyVerified =>
      DevConfig.enabled ||
      DevConfig.skipKycVerification ||
      isAutomatedKycVerified ||
      isManualKycVerified;



  void reset() {

    status = KycStatusModel.empty;

    manualStatus = ManualKycStatusModel.empty;

    isLoading = false;

    statusLoaded = false;

    error = null;

    kycPushDepth = 0;

    notifyListeners();

  }



  String _messageFromError(Object error, String fallback) {

    if (error is ApiException) return error.message;

    if (error is DioException && error.error is ApiException) {

      return (error.error as ApiException).message;

    }

    return fallback;

  }



  /// Primary status load — checks both the automated (Eko) flow and the
  /// legacy manual flow so `isFullyVerified` is accurate on app start.

  Future<void> loadStatus() async {
    await loadAutomatedStatus();
    await loadManualStatus();
  }

  Future<void> loadAutomatedStatus() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      status = await _kycRepo.fetchStatus();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'Could not load KYC status.');
    }
    isLoading = false;
    notifyListeners();
  }



  Future<void> loadManualStatus() async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      manualStatus = await _manualApi.fetchMe();

    } on ApiException catch (e) {

      error = e.message;

    } catch (e) {

      error = _messageFromError(e, 'Could not load KYC status.');

    }

    isLoading = false;

    statusLoaded = true;

    notifyListeners();

  }



  Future<bool> submitManualKyc({
    required String panNumber,
    required String fullName,
    required String dob,
    required List<XFile> panImages,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      manualStatus = await _manualApi.submitKyc(
        panNumber: panNumber,
        fullName: fullName,
        dob: dob,
        panImages: panImages,
      );
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'KYC submission failed.');
    }
    isLoading = false;
    notifyListeners();
    return false;
  }



  // Legacy Cashfree helpers (kept for bank/payment screens if needed)

  Future<bool> verifyPan(String pan, {String holderName = '', String? dob}) async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      status = await _kycRepo.verifyPan(pan, holderName: holderName, dob: dob);

      isLoading = false;

      notifyListeners();

      return status.panVerified;

    } on ApiException catch (e) {

      error = e.message;

    } catch (e) {

      error = _messageFromError(e, 'PAN verification failed.');

    }

    isLoading = false;

    notifyListeners();

    return false;

  }



  Future<bool> verifyBank({

    required String accountHolderName,

    required String accountNumber,

    required String confirmAccountNumber,

    required String ifsc,

  }) async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      status = await _kycRepo.verifyBank(

        accountHolderName: accountHolderName,

        accountNumber: accountNumber,

        confirmAccountNumber: confirmAccountNumber,

        ifsc: ifsc,

      );

      isLoading = false;

      notifyListeners();

      return status.bankVerified;

    } on ApiException catch (e) {

      error = e.message;

    } catch (e) {

      error = _messageFromError(e, 'Bank verification failed.');

    }

    isLoading = false;

    notifyListeners();

    return false;

  }



  Future<bool> runNameMatch() async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      status = await _kycRepo.runNameMatch();

      isLoading = false;

      notifyListeners();

      return status.nameMatchPassed;

    } on ApiException catch (e) {

      error = e.message;

    } catch (e) {

      error = _messageFromError(e, 'Name match failed.');

    }

    isLoading = false;

    notifyListeners();

    return false;

  }



  Future<PaymentSessionModel?> createPayment(double amount) async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      final session = await _paymentRepo.createPayment(amount);

      isLoading = false;

      notifyListeners();

      return session;

    } on ApiException catch (e) {

      error = e.message;

    } catch (_) {

      error = 'Payment could not be started.';

    }

    isLoading = false;

    notifyListeners();

    return null;

  }



  Future<WithdrawResultModel?> withdraw(double amount) async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      final result = await _paymentRepo.withdraw(amount);

      isLoading = false;

      notifyListeners();

      return result;

    } on ApiException catch (e) {

      error = e.message;

    } catch (_) {

      error = 'Withdrawal failed.';

    }

    isLoading = false;

    notifyListeners();

    return null;

  }

}


