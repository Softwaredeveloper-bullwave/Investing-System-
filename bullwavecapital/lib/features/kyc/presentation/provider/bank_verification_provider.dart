import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';

enum BankVerificationStep { details, verify, success }

class BankVerificationResult {
  final bool success;
  final String message;
  final String? nameAtBank;
  final String? nameMatchResult;
  final String? panRegisteredName;

  const BankVerificationResult({
    required this.success,
    required this.message,
    this.nameAtBank,
    this.nameMatchResult,
    this.panRegisteredName,
  });
}

class BankVerificationProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  String accountHolderName = '';
  String bankName = '';
  String accountNumber = '';
  String ifscCode = '';
  String panNumber = '';
  String nameAtBank = '';
  String nameMatchResult = '';
  String panRegisteredName = '';
  String? lastError;
  BankVerificationStep step = BankVerificationStep.details;
  bool isVerifying = false;
  bool isVerified = false;
  bool isHydrating = false;

  bool get isFormValid =>
      accountHolderName.length >= 3 &&
      bankName.length >= 3 &&
      accountNumber.length >= 9 &&
      _isValidIfsc(ifscCode) &&
      _isValidPan(panNumber);

  String get maskedAccountNumber {
    if (accountNumber.length < 4) return accountNumber;
    return '**** ${accountNumber.substring(accountNumber.length - 4)}';
  }

  double get progress {
    if (isVerified) return 1;
    if (step == BankVerificationStep.verify) return 0.75;
    var filled = 0;
    if (accountHolderName.isNotEmpty) filled++;
    if (bankName.isNotEmpty) filled++;
    if (accountNumber.isNotEmpty) filled++;
    if (_isValidIfsc(ifscCode)) filled++;
    if (_isValidPan(panNumber)) filled++;
    return filled / 5 * 0.6;
  }

  Future<void> hydrateFromServer() async {
    if (isHydrating) return;
    isHydrating = true;
    notifyListeners();
    try {
      final data = await _api.getBankAccount();
      if (data == null) {
        isVerified = false;
        return;
      }
      accountHolderName = data.accountHolderName;
      bankName = data.bankName;
      if (data.accountNumber.isNotEmpty) {
        accountNumber = data.accountNumber;
      }
      ifscCode = data.ifsc;
      panNumber = data.panNumber;
      nameAtBank = data.nameAtBank;
      nameMatchResult = data.nameMatchResult;
      panRegisteredName = data.panRegisteredName;
      isVerified = data.isVerified;
      if (isVerified) {
        step = BankVerificationStep.success;
      }
    } catch (_) {
      // Keep local state if fetch fails.
    } finally {
      isHydrating = false;
      notifyListeners();
    }
  }

  void updateAccountHolder(String value) {
    accountHolderName = value;
    notifyListeners();
  }

  void updateBankName(String value) {
    bankName = value;
    notifyListeners();
  }

  void updateAccountNumber(String value) {
    accountNumber = value;
    notifyListeners();
  }

  void updateIfsc(String value) {
    ifscCode = value.toUpperCase();
    notifyListeners();
  }

  void updatePan(String value) {
    panNumber = value.toUpperCase();
    notifyListeners();
  }

  bool proceedToVerify() {
    if (!isFormValid) return false;
    lastError = null;
    step = BankVerificationStep.verify;
    notifyListeners();
    return true;
  }

  Future<BankVerificationResult> verifyAccount() async {
    if (!isFormValid) {
      return const BankVerificationResult(success: false, message: 'Complete all fields.');
    }
    isVerifying = true;
    lastError = null;
    notifyListeners();
    try {
      await _api.saveBankAccount(
        accountHolderName: accountHolderName,
        bankName: bankName,
        accountNumber: accountNumber,
        ifsc: ifscCode,
        panNumber: panNumber,
      );
      final result = await _api.verifyBankAccount();
      isVerifying = false;
      if (result.success) {
        isVerified = true;
        nameAtBank = result.nameAtBank ?? nameAtBank;
        nameMatchResult = result.nameMatchResult ?? nameMatchResult;
        panRegisteredName = result.panRegisteredName ?? panRegisteredName;
        if (result.bank != null && result.bank!.isNotEmpty) {
          bankName = result.bank!;
        }
        step = BankVerificationStep.success;
        notifyListeners();
        return BankVerificationResult(
          success: true,
          message: result.message,
          nameAtBank: result.nameAtBank,
          nameMatchResult: result.nameMatchResult,
          panRegisteredName: result.panRegisteredName,
        );
      }
      lastError = result.message;
      notifyListeners();
      return BankVerificationResult(success: false, message: result.message);
    } on ApiException catch (e) {
      isVerifying = false;
      lastError = e.message;
      notifyListeners();
      return BankVerificationResult(success: false, message: e.message);
    } catch (_) {
      isVerifying = false;
      lastError = 'Verification failed. Please try again.';
      notifyListeners();
      return BankVerificationResult(success: false, message: lastError!);
    }
  }

  void resetToDetails() {
    step = BankVerificationStep.details;
    lastError = null;
    notifyListeners();
  }

  bool _isValidIfsc(String value) {
    return RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value);
  }

  bool _isValidPan(String value) {
    return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(value);
  }
}
