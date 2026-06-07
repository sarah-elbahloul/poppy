import 'package:flutter/material.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/services.dart';

/// The various states an entries-related operation can be in.
enum EntriesStatus { initial, loading, loaded, error }

/// Manages the state and business logic for journal entries.
///
/// **Offline-First Flow:**
/// 1. [fetchEntries] loads data from the local SQLite database immediately for instant UI feedback.
/// 2. It triggers a background synchronization via [SyncService].
/// 3. Once sync is complete, the provider reloads from the local database to pick up any remote changes.
class EntriesProvider extends ChangeNotifier {
  final _entriesService = EntriesService();
  final _photosService = PhotosService();
  final _sync = SyncService.instance;

  List<Entry> _entries = [];
  EntriesStatus _status = EntriesStatus.initial;
  String? _errorMessage;
  bool _isSyncing = false;

  // --- Filter State ---
  String? _query;
  String? _colorTag;
  DateTime? _fromDate;
  DateTime? _toDate;

  /// The complete list of cached entries.
  List<Entry> get entries => _entries;

  /// The list of entries filtered by the current search and filter criteria.
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

  /// Current status of the entries data layer.
  EntriesStatus get status => _status;

  /// The last error message encountered.
  String? get errorMessage => _errorMessage;

  /// Whether the initial data load is in progress.
  bool get isLoading => _status == EntriesStatus.loading;

  /// Whether a background synchronization with Supabase is currently running.
  bool get isSyncing => _isSyncing;

  // --- Filter API ---

  /// Updates the current filters and notifies listeners.
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

  /// Clears all active filters and notifies listeners.
  void clearFilters() {
    _query = null;
    _colorTag = null;
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  // --- CRUD Operations ---

  /// Loads entries from the local database immediately and initiates a background sync.
  Future<void> fetchEntries() async {
    _status = EntriesStatus.loading;
    notifyListeners();

    try {
      // Instant load from local cache.
      _entries = await _entriesService.fetchAll();
      _status = EntriesStatus.loaded;
      notifyListeners();

      // Initiate background synchronization.
      _isSyncing = true;
      notifyListeners();

      _sync.onSyncComplete = () async {
        try {
          _entries = await _entriesService.fetchAll();
          _isSyncing = false;
          notifyListeners();
        } catch (_) {
          _isSyncing = false;
          notifyListeners();
        }
      };

      await _sync.syncNow();
    } catch (e) {
      _status = EntriesStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Creates a new [entry] and updates the local state.
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

  /// Updates an existing [entry] and refreshes the local state.
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

  /// Deletes an entry by its [entryId] and removes associated photos.
  Future<bool> deleteEntry(String entryId) async {
    try {
      // Optimistic UI update: remove from memory immediately.
      _entries.removeWhere((e) => e.id == entryId);
      notifyListeners();

      // Best-effort photo cleanup.
      try {
        await _photosService.deleteAllForEntry(entryId);
      } catch (_) {
        // Non-fatal; server-side cleanup will handle it if offline.
      }

      // Mark for deletion in local DB and queue for sync.
      await _entriesService.delete(entryId);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Retrieves an entry by its [id] from the local cache.
  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Resets the provider state to its initial values.
  void clear() {
    _entries = [];
    _status = EntriesStatus.initial;
    _errorMessage = null;
    _isSyncing = false;
    clearFilters();
  }

  /// Clears the current error message and notifies listeners.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
