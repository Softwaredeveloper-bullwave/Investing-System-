import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';

class KycProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  static const _kycSteps = [
    {'title': 'Upload PAN', 'key': 'pan'},
    {'title': 'Upload Aadhaar Front', 'key': 'aadhaar_front'},
    {'title': 'Upload Aadhaar Back', 'key': 'aadhaar_back'},
    {'title': 'Selfie Upload', 'key': 'selfie'},
    {'title': 'Address Proof', 'key': 'address'},
  ];

  int _currentStep = 0;
  final Map<String, bool> _uploads = {};
  bool _isSubmitting = false;

  int get currentStep => _currentStep;
  int get totalSteps => _kycSteps.length;
  double get progress => (_currentStep + 1) / totalSteps;
  bool get isSubmitting => _isSubmitting;
  List<Map<String, String>> get steps => _kycSteps;

  bool isStepUploaded(String key) => _uploads[key] ?? false;

  Future<void> uploadDocument(String key) async {
    try {
      await _api.uploadKycDocument(key);
      _uploads[key] = true;
      if (_currentStep < totalSteps - 1) {
        _currentStep++;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> submit() async {
    _isSubmitting = true;
    notifyListeners();
    try {
      await _api.submitKyc();
      _isSubmitting = false;
      notifyListeners();
      return _uploads.length >= totalSteps;
    } catch (_) {
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }
}
