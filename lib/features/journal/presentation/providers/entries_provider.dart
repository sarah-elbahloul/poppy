import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/journal/data/services/entries_service.dart';
import 'package:poppy/features/journal/data/services/photos_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Provider
// ─────────────────────────────────────────────────────────────

/// Represents the possible states of the entries fetching process.
enum EntriesStatus { 
  /// The initial state before any fetching starts.
  initial, 
  /// The state when entries are being fetched.
  loading, 
  /// The state when entries have been successfully loaded.
  loaded, 
  /// The state when an error occurred during fetching.
  error 
}

/// Provider managing the state and business logic for journal entries.
///
/// Handles fetching, filtering, creating, updating, and deleting entries,
/// and manages their synchronization state.
class EntriesProvider extends ChangeNotifier {
  final _entriesService = EntriesService();
  final _photosService = PhotosService();
  final _sync = SyncService.instance;

  List<Entry> _entries = [];
  EntriesStatus _status = EntriesStatus.initial;
  String? _errorMessage;
  bool _isSyncing = false;

  String? _query;
  String? _colorTag;
  DateTime? _fromDate;
  DateTime? _toDate;

  /// Returns the full list of journal entries.
  List<Entry> get entries => _entries;

  /// Returns a filtered and sorted list of entries based on current filter criteria.
  ///
  /// Filters by title/content [query], [colorTag], [fromDate], and [toDate].
  /// Entries are sorted by date in descending order.
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

  /// The current status of the entries provider.
  EntriesStatus get status => _status;

  /// The most recent error message, if any.
  String? get errorMessage => _errorMessage;

  /// Whether entries are currently being loaded.
  bool get isLoading => _status == EntriesStatus.loading;

  /// Whether a synchronization operation is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Sets the filtering criteria for the entries list.
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

  /// Clears all active filters.
  void clearFilters() {
    _query = null;
    _colorTag = null;
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  /// Fetches entries from the local database and initiates a remote sync.
  Future<void> fetchEntries() async {
    _status = EntriesStatus.loading;
    notifyListeners();

    try {
      _entries = await _entriesService.fetchAll();
      _status = EntriesStatus.loaded;
      notifyListeners();

      _isSyncing = true;
      notifyListeners();

      _sync.onSyncComplete = () async {
        _sync.onSyncComplete = null;
        try {
          _entries = await _entriesService.fetchAll();
        } catch (_) {
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

  /// Creates a new journal entry.
  ///
  /// Returns the created [Entry] or null if the operation failed.
  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _entriesService.create(entry);

      // Ensure that if it was created with empty title/content, we keep the original intent
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

  /// Updates an existing journal entry.
  ///
  /// Returns the updated [Entry] or null if the operation failed.
  Future<Entry?> updateEntry(Entry entry) async {
    try {
      final saved = await _entriesService.update(entry);

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

  /// Updates multiple entries at once.
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

  /// Deletes a single entry by its [entryId].
  Future<bool> deleteEntry(String entryId) async {
    try {
      _entries.removeWhere((e) => e.id == entryId);
      notifyListeners();

      try {
        await _photosService.deleteAllForEntry(entryId);
      } catch (_) {}

      await _entriesService.delete(entryId);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deletes multiple entries specified by [entryIds].
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

  /// Updates all entries that were using [oldTag] to use [newTag].
  Future<void> propagateTagEdit(TagColorData oldTag, TagColorData newTag) async {
    final affected = _entries.where((e) => e.colorTag.id == oldTag.id).toList();
    if (affected.isEmpty) return;

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

    for (final entry in affected) {
      final updated = entry.copyWith(colorTag: newTag);
      final saved = await _entriesService.update(updated);
      final index = _entries.indexWhere((e) => e.id == saved.id);
      if (index != -1) _entries[index] = saved;
    }
    notifyListeners();
    _sync.syncNow();
  }

  /// Updates all entries that were using [deletedTag] to use [fallbackTag].
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

  /// Returns an entry by its [id], or null if not found.
  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clears all local state and filters.
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