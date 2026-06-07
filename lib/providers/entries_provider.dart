import 'package:flutter/material.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/services.dart';

/// Represents the status of the entries loading process.
enum EntriesStatus { initial, loading, loaded, error }

/// Poppy — Entries Provider
///
/// Manages the state of journal entries, including fetching, filtering, 
/// creating, updating, and deleting entries.
class EntriesProvider extends ChangeNotifier {
  final _entriesService = EntriesService();
  final _photosService = PhotosService();

  List<Entry> _entries = [];
  EntriesStatus _status = EntriesStatus.initial;
  String? _errorMessage;

  // --- Filter State ---
  String? _query;
  String? _colorTag;
  DateTime? _fromDate;
  DateTime? _toDate;

  // --- Getters ---
  List<Entry> get entries => _entries;

  /// Returns the list of entries filtered by the current criteria.
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

  // --- Filter API ---

  /// Sets the filters for the entries list.
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

  /// Clears all active filters.
  void clearFilters() {
    _query = null;
    _colorTag = null;
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  // --- CRUD Operations ---

  /// Fetches all entries from the service layer.
  Future<void> fetchEntries() async {
    _status = EntriesStatus.loading;
    notifyListeners();
    try {
      _entries = await _entriesService.fetchAll();
      _status = EntriesStatus.loaded;
    } catch (e) {
      _status = EntriesStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Creates a new entry and updates the local state.
  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _entriesService.create(entry);
      _entries.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Updates an existing entry and refreshes the local state.
  Future<bool> updateEntry(Entry entry) async {
    try {
      final updated = await _entriesService.update(entry);

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

  /// Deletes an entry and its associated photos.
  Future<bool> deleteEntry(String entryId) async {
    try {
      await _photosService.deleteAllForEntry(entryId);
      await _entriesService.delete(entryId);
      _entries.removeWhere((e) => e.id == entryId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Returns an entry by its ID from the local cache.
  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clears all entries and resets the provider state.
  void clear() {
    _entries = [];
    _status = EntriesStatus.initial;
    _errorMessage = null;
    clearFilters();
  }

  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
