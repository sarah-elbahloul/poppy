import 'package:flutter/material.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/entries_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Provider
//  Location: lib/providers/entries_provider.dart
//
//  Holds the in-memory list of diary entries and exposes
//  methods that the UI calls. All actual database work is
//  delegated to EntriesService.
// ─────────────────────────────────────────────────────────────

enum EntriesStatus { initial, loading, loaded, error }

class EntriesProvider extends ChangeNotifier {
  final _service = EntriesService();

  List<Entry> _entries = [];
  List<Entry> _searchResults = [];
  EntriesStatus _status = EntriesStatus.initial;
  String? _errorMessage;
  bool _isSearching = false;

  List<Entry> get entries => _entries;
  List<Entry> get searchResults => _searchResults;
  EntriesStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == EntriesStatus.loading;
  bool get isSearching => _isSearching;

  // ── Fetch all entries ─────────────────────────────────────

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

  // ── Create ────────────────────────────────────────────────

  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _service.create(entry);
      // Insert at the top — newest first
      _entries.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ── Update ────────────────────────────────────────────────

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

  // ── Delete ────────────────────────────────────────────────

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

  // ── Search ────────────────────────────────────────────────

  Future<void> search({
    String? query,
    String? colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _service.search(
        query: query,
        colorTag: colorTag,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _searchResults = [];
    }
    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  // ── Single entry lookup ───────────────────────────────────
  // Used by EntryDetailScreen and WriteScreen — avoids a
  // second network call if the entry is already in memory.

  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Clear on sign out ─────────────────────────────────────

  void clear() {
    _entries = [];
    _searchResults = [];
    _status = EntriesStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}