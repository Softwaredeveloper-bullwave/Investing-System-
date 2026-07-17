import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/referral_model.dart';
import '../../../../models/support_model.dart';

class SupportProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  bool _isLoading = true;
  List<SupportFaq> _faqs = [];
  List<SupportTicketModel> _tickets = [];

  bool get isLoading => _isLoading;
  List<SupportFaq> get faqs => _faqs;
  List<SupportTicketModel> get tickets => _tickets;

  SupportProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _faqs = await _api.getSupportFaqs();
      _tickets = await _api.getSupportTickets();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> raiseTicket(String subject, {String message = ''}) async {
    try {
      await _api.createSupportTicket(subject: subject, message: message);
      await loadData();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ReferralProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  bool _isLoading = false;
  bool _isApplying = false;
  String? _error;
  ReferralModel? _referral;

  bool get isLoading => _isLoading;
  bool get isApplying => _isApplying;
  String? get error => _error;
  ReferralModel? get referral => _referral;

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _referral = await _api.getReferrals();
    } on ApiException catch (e) {
      _error = e.message;
      _referral = null;
    } catch (_) {
      _error = 'Could not load referral details. Pull to refresh.';
      _referral = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<ApplyReferralResult?> applyReferralCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      _error = 'Enter a referral code.';
      notifyListeners();
      return null;
    }

    _isApplying = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.applyReferralCode(trimmed);
      await loadData();
      _isApplying = false;
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      _error = e.message;
      _isApplying = false;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Failed to apply referral code.';
      _isApplying = false;
      notifyListeners();
      return null;
    }
  }
}
