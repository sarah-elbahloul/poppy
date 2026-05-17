import 'package:flutter/material.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/entries_service.dart';

enum EntriesStatus { initial, loading, loaded, error }

class EntriesProvider extends ChangeNotifier {
  final _service = EntriesService();

  List<Entry> _entries = [];
  EntriesStatus _status = EntriesStatus.initial;
  String? _errorMessage;

  // ─────────────────────────────────────────────
  // FILTER STATE
  // ─────────────────────────────────────────────
  String? _query;
  String? _colorTag;
  DateTime? _fromDate;
  DateTime? _toDate;

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────
  List<Entry> get entries => _entries;

  List<Entry> get filteredEntries {
    return _entries.where((e) {
      final matchesQuery = _query == null ||
          _query!.isEmpty ||
          e.title.toLowerCase().contains(_query!) ||
          e.content.toLowerCase().contains(_query!);

      final matchesColor =
          _colorTag == null || e.colorTag.dbValue == _colorTag;

      final matchesFrom =
          _fromDate == null || !e.entryDate.isBefore(_fromDate!);

      final matchesTo =
          _toDate == null ||
              e.entryDate.isBefore(_toDate!.add(const Duration(days: 1)));

      return matchesQuery && matchesColor && matchesFrom && matchesTo;
    }).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  EntriesStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == EntriesStatus.loading;

  // ─────────────────────────────────────────────
  // FILTER API
  // ─────────────────────────────────────────────
  void setFilters({
    String? query,
    String? colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    _query = query ?? _query;
    _colorTag = colorTag;
    _fromDate = fromDate;
    _toDate = toDate;
    notifyListeners();
  }

  void clearFilters() {
    _query = null;
    _colorTag = null;
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────
  Future<void> fetchEntries() async {
    _status = EntriesStatus.loading;
    notifyListeners();
    try {
      _entries = await _service.fetchAll();
      _status = EntriesStatus.loaded;
    } catch (e) {
      _status = EntriesStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _service.create(entry);
      _entries.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEntry(Entry entry) async {
    try {
      final updated = await _service.update(entry);

      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = updated;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEntry(String entryId) async {
    try {
      await _service.delete(entryId);
      _entries.removeWhere((e) => e.id == entryId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _entries = [];
    _status = EntriesStatus.initial;
    _errorMessage = null;
    clearFilters();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}