import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  bool _isLoading = true;
  WalletModel _wallet = const WalletModel(
    balance: 0,
    bankName: '',
    accountNumber: '',
    ifsc: '',
  );
  List<WalletTransaction> _transactions = [];

  bool get isLoading => _isLoading;
  WalletModel get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;

  WalletProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _wallet = await _api.getWallet();
      _transactions = await _api.getWalletTransactions();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> withdraw(double amount) async {
    try {
      await _api.withdraw(amount);
      await loadData();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deposit(double amount) async {
    try {
      await _api.deposit(amount);
      await loadData();
      return true;
    } catch (_) {
      return false;
    }
  }
}
