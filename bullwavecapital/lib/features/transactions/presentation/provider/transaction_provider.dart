import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../models/transaction_model.dart';

class TransactionProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  bool _isLoading = true;
  String _searchQuery = '';
  TransactionType _selectedTab = TransactionType.all;
  int _currentPage = 1;
  static const int _pageSize = 4;
  List<TransactionModel> _transactions = [];

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  TransactionType get selectedTab => _selectedTab;
  int get currentPage => _currentPage;
  int get totalPages => (_filteredTransactions.length / _pageSize).ceil().clamp(1, 999);
  List<TransactionModel> get allTransactions => _transactions;

  TransactionProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _transactions = await _api.getTransactions();
    } catch (_) {
      _transactions = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  List<TransactionModel> get _filteredTransactions {
    var list = _transactions;
    if (_selectedTab != TransactionType.all) {
      list = list.where((t) => t.type == _selectedTab).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((t) =>
              t.referenceId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return list;
  }

  List<TransactionModel> get paginatedTransactions {
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredTransactions.length);
    if (start >= _filteredTransactions.length) return [];
    return _filteredTransactions.sublist(start, end);
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _currentPage = 1;
    notifyListeners();
  }

  void setTab(TransactionType tab) {
    _selectedTab = tab;
    _currentPage = 1;
    notifyListeners();
  }

  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }
}
