import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_exception.dart';
import '../../models/fno_status_model.dart';
import '../../services/fno_api_service.dart';

class FnoFlowProvider extends ChangeNotifier {
  final _api = FnoApiService.instance;

  FnoStatusModel status = FnoStatusModel.empty;
  bool isLoading = false;
  bool statusLoaded = false;
  String? error;

  bool get isVerified => status.isVerified;
  bool get isPending => status.isPending;
  bool get isRejected => status.isRejected;

  Future<void> ensureLoaded() async {
    if (statusLoaded && !isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      status = await _api.fetchMe();
      statusLoaded = true;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
      statusLoaded = true;
    } catch (_) {
      error = 'Could not load F&O eligibility status.';
      statusLoaded = true;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> submitDocument({
    required String proofType,
    required XFile file,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      status = await _api.submitProof(proofType: proofType, document: file);
      statusLoaded = true;
      isLoading = false;
      error = null;
      notifyListeners();
      return status.isVerified
          ? 'F&O access enabled. You can now trade futures and options.'
          : 'Submitted for admin review. You will be notified once F&O access is approved.';
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not submit F&O verification.';
    }
    isLoading = false;
    notifyListeners();
    return null;
  }

  Future<String?> submitPortfolioHolding() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      status = await _api.submitProof(proofType: 'portfolio_holding');
      statusLoaded = true;
      isLoading = false;
      notifyListeners();
      if (status.isVerified) {
        return 'Portfolio verified. F&O access is now enabled.';
      }
      return 'Could not verify portfolio holding.';
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not verify portfolio holding.';
    }
    isLoading = false;
    notifyListeners();
    return null;
  }
}
