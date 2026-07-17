import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/trader_note_model.dart';

class NotesProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<TraderNoteModel> _notes = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _categoryFilter;

  List<TraderNoteModel> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get categoryFilter => _categoryFilter;

  List<TraderNoteModel> get pinnedNotes =>
      _notes.where((n) => n.isPinned).toList();

  Future<void> load({String? category, String? search}) async {
    _isLoading = true;
    _error = null;
    if (category != null) _categoryFilter = category.isEmpty ? null : category;
    if (search != null) _searchQuery = search;
    notifyListeners();
    try {
      _notes = await _api.getTraderNotes(
        category: _categoryFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
    } on ApiException catch (e) {
      _error = e.message;
      _notes = [];
    } catch (_) {
      _error = 'Could not load notes. Check your connection.';
      _notes = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();

  void setSearchQuery(String value) {
    _searchQuery = value;
    load(search: value);
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    load(category: category ?? '');
  }

  Future<TraderNoteModel?> saveNote({
    String? id,
    required String title,
    required String body,
    String symbol = '',
    String category = 'general',
    bool isPinned = false,
  }) async {
    try {
      final TraderNoteModel saved;
      if (id == null || id.isEmpty) {
        saved = await _api.createTraderNote(
          title: title,
          body: body,
          symbol: symbol,
          category: category,
          isPinned: isPinned,
        );
        _notes = [saved, ..._notes];
      } else {
        saved = await _api.updateTraderNote(
          id,
          title: title,
          body: body,
          symbol: symbol,
          category: category,
          isPinned: isPinned,
        );
        _notes = [
          for (final note in _notes)
            if (note.id == id) saved else note,
        ];
      }
      _notes.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      _error = null;
      notifyListeners();
      return saved;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Could not save note.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> togglePin(TraderNoteModel note) async {
    final updated = await saveNote(
      id: note.id,
      title: note.title,
      body: note.body,
      symbol: note.symbol,
      category: note.category,
      isPinned: !note.isPinned,
    );
    return updated != null;
  }

  Future<bool> deleteNote(String id) async {
    try {
      await _api.deleteTraderNote(id);
      _notes = _notes.where((n) => n.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Could not delete note.';
      notifyListeners();
      return false;
    }
  }
}
