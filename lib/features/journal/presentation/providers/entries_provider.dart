import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/journal/data/services/entries_service.dart';
import 'package:poppy/features/journal/data/services/photos_service.dart';
import 'package:poppy/core/services/local_db_service.dart';
import 'package:poppy/core/services/sync_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Provider
//  Location: lib/features/journal/presentation/providers/entries_provider.dart
// ─────────────────────────────────────────────────────────────

enum EntriesStatus { initial, loading, loaded, error }

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
  bool get isSyncing => _isSyncing;

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

  void clearFilters() {
    _query = null;
    _colorTag = null;
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

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

  Future<Entry?> createEntry(Entry entry) async {
    try {
      final created = await _entriesService.create(entry);

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

  Entry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _sync.onSyncComplete = null;
    _entries = [];
    _status = EntriesStatus.initial;
    _errorMessage = null;
    _isSyncing = false;
    clearFilters();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
