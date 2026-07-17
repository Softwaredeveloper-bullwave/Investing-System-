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



  /// Manual admin-reviewed KYC (replaces Cashfree PAN flow).

  bool get isManualKycVerified => manualStatus.isVerified;



  /// Markets & trading access.

  bool get isFullyVerified => DevConfig.enabled || isManualKycVerified;



  void reset() {

    status = KycStatusModel.empty;

    manualStatus = ManualKycStatusModel.empty;

    isLoading = false;

    statusLoaded = false;

    error = null;

    notifyListeners();

  }



  String _messageFromError(Object error, String fallback) {

    if (error is ApiException) return error.message;

    if (error is DioException && error.error is ApiException) {

      return (error.error as ApiException).message;

    }

    return fallback;

  }



  /// Primary status load — uses GET /kyc/me for routing after OTP.

  Future<void> loadStatus() => loadManualStatus();



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

  Future<bool> verifyPan(String pan, {String holderName = ''}) async {

    isLoading = true;

    error = null;

    notifyListeners();

    try {

      status = await _kycRepo.verifyPan(pan, holderName: holderName);

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


