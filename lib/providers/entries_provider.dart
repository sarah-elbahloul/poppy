import 'package:flutter/material.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/services.dart';
import 'package:poppy/core/style/style.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Provider
//  Location: lib/providers/entries_provider.dart
// ─────────────────────────────────────────────────────────────

/// The various states an entries-related operation can be in.
enum EntriesStatus { initial, loading, loaded, error }

/// Manages the state and business logic for journal entries.
///
/// This provider implements an **Offline-First Flow**:
/// 1. Loads data from the local SQLite database immediately for instant UI feedback.
/// 2. Triggers background synchronization via [SyncService].
/// 3. Updates local state once remote changes are reconciled.
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

  // ─────────────────────────────────────────────────────────────
  //  Getters
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  //  Filter API
  // ─────────────────────────────────────────────────────────────

  /// Updates the current filters and notifies listeners.
  void setFilters({
    String? query,
    String? colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    _query = query;
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

  // ─────────────────────────────────────────────────────────────
  //  CRUD Operations
  // ─────────────────────────────────────────────────────────────

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

      // Register a one-shot completion handler.
      _sync.onSyncComplete = () async {
        _sync.onSyncComplete = null; 
        try {
          _entries = await _entriesService.fetchAll();
        } catch (_) {
          // Keep the last-known local data on error.
        } finally {
          _isSyncing = false;
          notifyListeners();
        }
      };

      await _sync.syncNow();
    } catch (e) {
      _isSyncing = false;
      _status = EntriesStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Creates a new entry and updates the local state.
  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _entriesService.create(entry);

      // Defensive patch: Ensure title/content are preserved even if DB return is partial.
      final needsPatch = (created.title.isEmpty && entry.title.isNotEmpty) ||
          (created.content.isEmpty && entry.content.isNotEmpty);

      final safeCreated = needsPatch
          ? created.copyWith(title: entry.title, content: entry.content)
          : created;

      _entries.add(safeCreated);
      notifyListeners();
      return safeCreated;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Updates an existing entry and refreshes the local state.
  Future<Entry?> updateEntry(Entry entry) async {
    try {
      final saved = await _entriesService.update(entry);

      // Reconcile caller's latest text with service's sync status.
      final reconciled = entry.copyWith(syncStatus: saved.syncStatus);

      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = reconciled;
        notifyListeners();
      }

      return reconciled;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Updates multiple entries in bulk and refreshes the local state.
  Future<bool> updateEntries(List<Entry> updatedEntries) async {
    try {
      final results = await Future.wait(
        updatedEntries.map((e) => _entriesService.update(e)),
      );

      for (final updated in results) {
        final index = _entries.indexWhere((e) => e.id == updated.id);
        if (index != -1) {
          _entries[index] = updated;
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deletes an entry by its ID and removes associated photos.
  Future<bool> deleteEntry(String entryId) async {
    try {
      // Optimistic UI update: remove from memory immediately.
      _entries.removeWhere((e) => e.id == entryId);
      notifyListeners();

      // Best-effort photo cleanup.
      try {
        await _photosService.deleteAllForEntry(entryId);
      } catch (_) {}

      // Mark for deletion in local DB and queue for sync.
      await _entriesService.delete(entryId);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deletes multiple entries by their IDs and removes associated photos.
  Future<bool> deleteEntries(List<String> entryIds) async {
    try {
      _entries.removeWhere((e) => entryIds.contains(e.id));
      notifyListeners();

      await Future.wait(
          entryIds.map((id) => _photosService.deleteAllForEntry(id).catchError((_) {}))
      );

      await _entriesService.deleteBatch(entryIds);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Tag Propagation
  // ─────────────────────────────────────────────────────────────

  /// Updates every in-memory entry that uses [oldTag] to reference [newTag].
  Future<void> propagateTagEdit(TagColorData oldTag, TagColorData newTag) async {
    final affected = _entries.where((e) => e.colorTag.id == oldTag.id).toList();
    if (affected.isEmpty) return;

    // Optimistic UI update
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].colorTag.id == oldTag.id) {
        final current = _entries[i];
        _entries[i] = current.copyWith(
          colorTag: newTag,
          syncStatus: current.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate,
        );
      }
    }
    notifyListeners();

    // Persist to SQLite
    for (final entry in affected) {
      final updated = entry.copyWith(colorTag: newTag);
      final saved = await _entriesService.update(updated);
      final index = _entries.indexWhere((e) => e.id == saved.id);
      if (index != -1) _entries[index] = saved;
    }
    notifyListeners();
    _sync.syncNow();
  }

  /// Reassigns any entry referencing [deletedTag] to [fallbackTag].
  Future<void> propagateTagDeletion(TagColorData deletedTag, TagColorData fallbackTag) async {
    final affected = _entries.where((e) => e.colorTag.id == deletedTag.id).toList();
    if (affected.isEmpty) return;

    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].colorTag.id == deletedTag.id) {
        final current = _entries[i];
        _entries[i] = current.copyWith(
          colorTag: fallbackTag,
          syncStatus: current.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate,
        );
      }
    }
    notifyListeners();

    for (final entry in affected) {
      final updated = entry.copyWith(colorTag: fallbackTag);
      final saved = await _entriesService.update(updated);
      final index = _entries.indexWhere((e) => e.id == saved.id);
      if (index != -1) _entries[index] = saved;
    }
    notifyListeners();
    _sync.syncNow();
  }

  // ─────────────────────────────────────────────────────────────
  //  Utility Methods
  // ─────────────────────────────────────────────────────────────

  /// Retrieves an entry by its ID from the local cache.
  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Resets the provider state and cancels pending sync callbacks.
  void clear() {
    _sync.onSyncComplete = null;
    _entries = [];
    _status = EntriesStatus.initial;
    _errorMessage = null;
    _isSyncing = false;
    clearFilters();
  }

  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
