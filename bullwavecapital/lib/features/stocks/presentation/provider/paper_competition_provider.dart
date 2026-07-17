import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/paper_competition_model.dart';

class PaperCompetitionProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  PaperRiskMeterModel? _riskMeter;
  List<PaperCompetitionModel> _competitions = [];
  PaperCompetitionModel? _selected;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  PaperRiskMeterModel? get riskMeter => _riskMeter;
  List<PaperCompetitionModel> get competitions => _competitions;
  PaperCompetitionModel? get selected => _selected;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getPaperRiskMeter(),
        _api.getPaperCompetitions(),
      ]);
      _riskMeter = results[0] as PaperRiskMeterModel;
      _competitions = results[1] as List<PaperCompetitionModel>;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load paper trading extras.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshRiskOnly() async {
    try {
      _riskMeter = await _api.getPaperRiskMeter();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> createCompetition({
    String name = '',
    double startingBalance = 100000,
    int durationDays = 7,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final created = await _api.createPaperCompetition(
        name: name,
        startingBalance: startingBalance,
        durationDays: durationDays,
      );
      _competitions = [created, ..._competitions.where((c) => c.id != created.id)];
      _selected = created;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to create competition.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> joinCompetition(String code) async {
    _isSaving = true;
    notifyListeners();
    try {
      final joined = await _api.joinPaperCompetition(code);
      _competitions = [joined, ..._competitions.where((c) => c.id != joined.id)];
      _selected = joined;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to join competition.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadCompetition(String id) async {
    try {
      _selected = await _api.getPaperCompetition(id);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }
}
