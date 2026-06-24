import 'package:flutter/material.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/services.dart';

import '../core/style/app_colors.dart';

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
    _query = query ?? null;
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

      // Register a one-shot completion handler.  We replace any previous
      // handler so a rapid double-call to fetchEntries does not result in
      // two stale closures fighting over the list.
      _sync.onSyncComplete = () async {
        _sync.onSyncComplete = null; // consume immediately — no double-fire
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

  /// Creates a new [entry] and updates the local state.
  ///
  /// Uses the service-generated ID from the return value but **preserves
  /// title and content from the caller's input** to guard against any
  /// column-mapping bug in the service/DB layer that could return empty
  /// text fields.
  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _entriesService.create(entry);

      // Defensive: if the service lost title or content during the
      // round-trip (e.g. SQLite column name mismatch), patch the
      // returned entry with the data we know is correct.
      final needsPatch = (created.title.isEmpty && entry.title.isNotEmpty) ||
          (created.content.isEmpty && entry.content.isNotEmpty);

      final safeCreated = needsPatch
          ? created.copyWith(
        title: entry.title,
        content: entry.content,
      )
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

  /// Updates an existing [entry] and refreshes the local state.
  ///
  /// Returns the saved [Entry] (with the authoritative [Entry.syncStatus]
  /// reflecting what was actually persisted), or `null` on failure — mirrors
  /// [createEntry]'s contract so callers always have a correct, reconciled
  /// copy to hold onto rather than re-using their own stale local copy.
  ///
  /// Title/content always come from the caller, since [EntriesService.update]
  /// never re-derives them from local storage.
  Future<Entry?> updateEntry(Entry entry) async {
    try {
      final saved = await _entriesService.update(entry);

      // The caller's title/content are known-correct (built directly from
      // the text controllers); the service's syncStatus is the
      // authoritative reflection of what was just persisted to SQLite.
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
      // For now, we update them sequentially but wait for all to finish
      // before notifying listeners once.
      // Ideally, EntriesService would have a batch update as well.
      //
      // Use the service's returned entries (not the caller's input) for the
      // in-memory list: EntriesService.update() stamps the correct
      // pending_create/pending_update syncStatus, which the caller's copy
      // doesn't carry. Using the caller's copy directly left the sync-status
      // dot on entry cards out of date until the next full fetchEntries().
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

  /// Deletes multiple entries by their [entryIds] and removes associated photos.
  Future<bool> deleteEntries(List<String> entryIds) async {
    try {
      // Optimistic UI update: remove from memory immediately.
      _entries.removeWhere((e) => entryIds.contains(e.id));
      notifyListeners();

      // Best-effort photo cleanup for all entries.
      // We do this in parallel to speed it up.
      await Future.wait(
          entryIds.map((id) => _photosService.deleteAllForEntry(id).catchError((_) {}))
      );

      // Mark for deletion in local DB and queue for sync.
      await _entriesService.deleteBatch(entryIds);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- Tag Propagation ---

  /// Called when a tag is renamed or recolored.
  ///
  /// Updates every in-memory entry that uses [oldTag] to reference [newTag],
  /// persists the change to SQLite (marking each affected entry as
  /// [SyncStatus.pendingUpdate]), and triggers a background sync so Supabase
  /// also receives the colour_tag update.
  ///
  /// Both online and offline users will see the change immediately in the UI,
  /// and the sync indicator dot on each card shows that the update is queued.
  Future<void> propagateTagEdit(
      TagColorData oldTag,
      TagColorData newTag,
      ) async {
    // Entries whose colorTag id matches the edited tag.
    final affected = _entries
        .where((e) => e.colorTag.id == oldTag.id)
        .toList();

    if (affected.isEmpty) return;

    // Optimistic in-memory update — immediate UI feedback.
    // Explicitly pass title & content to guard against a copyWith that
    // resets unspecified fields to defaults. Also set syncStatus so the
    // pending-sync dot on the entry card actually appears right away, as
    // promised by the doc comment above — a copyWith that omits syncStatus
    // would otherwise leave already-synced entries looking synced even
    // though they now have an unsynced local change.
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].colorTag.id == oldTag.id) {
        final current = _entries[i];
        _entries[i] = current.copyWith(
          colorTag: newTag,
          title: current.title,
          content: current.content,
          syncStatus: current.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate,
        );
      }
    }
    notifyListeners();

    // Persist each change to SQLite (queues a pending_update for sync) and
    // reconcile the in-memory entry with the service's returned copy, which
    // is the authoritative source for syncStatus/updatedAt after the write.
    for (final entry in affected) {
      final updated = entry.copyWith(
        colorTag: newTag,
        title: entry.title,
        content: entry.content,
      );
      final saved = await _entriesService.update(updated);
      final index = _entries.indexWhere((e) => e.id == saved.id);
      if (index != -1) _entries[index] = saved;
    }
    notifyListeners();

    // Trigger background sync so Supabase is updated when online.
    _sync.syncNow();
  }

  /// Called when a tag is deleted.
  ///
  /// Any entry referencing [deletedTag] is reassigned to [fallbackTag]
  /// (typically [EntryTags.defaultColor]). The change is written to SQLite
  /// immediately so it survives app restarts, and is queued for Supabase sync.
  Future<void> propagateTagDeletion(
      TagColorData deletedTag,
      TagColorData fallbackTag,
      ) async {
    final affected = _entries
        .where((e) => e.colorTag.id == deletedTag.id)
        .toList();

    if (affected.isEmpty) return;

    // Optimistic in-memory update. Set syncStatus for the same reason as in
    // propagateTagEdit — so the pending-sync dot reflects reality right away.
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].colorTag.id == deletedTag.id) {
        final current = _entries[i];
        _entries[i] = current.copyWith(
          colorTag: fallbackTag,
          title: current.title,
          content: current.content,
          syncStatus: current.syncStatus == SyncStatus.pendingCreate
              ? SyncStatus.pendingCreate
              : SyncStatus.pendingUpdate,
        );
      }
    }
    notifyListeners();

    // Persist to SQLite and reconcile with the service's returned copy.
    for (final entry in affected) {
      final updated = entry.copyWith(
        colorTag: fallbackTag,
        title: entry.title,
        content: entry.content,
      );
      final saved = await _entriesService.update(updated);
      final index = _entries.indexWhere((e) => e.id == saved.id);
      if (index != -1) _entries[index] = saved;
    }
    notifyListeners();

    _sync.syncNow();
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
  ///
  /// Also cancels any pending sync callback so in-flight syncs from the
  /// previous session cannot overwrite the cleared state.
  void clear() {
    _sync.onSyncComplete = null;
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