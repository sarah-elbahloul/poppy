import 'dart:convert';

import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Service
//  Location: lib/services/entries_service.dart
//
//  All DB rows use title_enc and content_enc (JSONB).
//  There are no plain title or content columns in the schema.
//
//  Write path: plaintext → encrypt → store title_enc/content_enc
//  Read path:  fetch title_enc/content_enc → decrypt → Entry model
//
//  Search: client-side only (content is encrypted server-side)
// ─────────────────────────────────────────────────────────────

class EntriesService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  // ── Fetch all ─────────────────────────────────────────────

  Future<List<Entry>> fetchAll() async {
    final response = await _client
        .from(DBTable.entries)
        .select()
        .order(DBColumn.entryDate, ascending: false);

    return _decryptList(response as List);
  }

  // ── Create ────────────────────────────────────────────────

  Future<Entry> create(Entry entry) async {
    final map = await _buildEncryptedMap(entry);
    map[DBColumn.userId] = SupabaseConfig.userId;

    final response = await _client
        .from(DBTable.entries)
        .insert(map)
        .select()
        .single();

    return _decryptSingle(response as Map<String, dynamic>);
  }

  // ── Update ────────────────────────────────────────────────

  Future<Entry> update(Entry entry) async {
    final map = await _buildEncryptedMap(entry);
    map[DBColumn.updatedAt] = DateTime.now().toIso8601String();

    final response = await _client
        .from(DBTable.entries)
        .update(map)
        .eq(DBColumn.id,     entry.id)
        .eq(DBColumn.userId, SupabaseConfig.userId)
        .select()
        .single();

    return _decryptSingle(response as Map<String, dynamic>);
  }

  // ── Delete ────────────────────────────────────────────────

  Future<void> delete(String entryId) async {
    await _client
        .from(DBTable.entries)
        .delete()
        .eq(DBColumn.id,     entryId)
        .eq(DBColumn.userId, SupabaseConfig.userId);
  }

  // ── Search (client-side) ──────────────────────────────────
  // All entries are fetched and decrypted, then filtered in memory.

  Future<List<Entry>> search({
    String?   query,
    String?   colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var entries = await fetchAll();

    if (colorTag != null && colorTag.isNotEmpty) {
      entries = entries
          .where((e) => e.colorTag.dbValue == colorTag)
          .toList();
    }
    if (fromDate != null) {
      entries = entries
          .where((e) => !e.entryDate.isBefore(fromDate))
          .toList();
    }
    if (toDate != null) {
      final inclusive = toDate.add(const Duration(days: 1));
      entries = entries
          .where((e) => e.entryDate.isBefore(inclusive))
          .toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      entries = entries.where((e) =>
      e.title.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q)).toList();
    }

    return entries;
  }

  // ── Encryption helpers ────────────────────────────────────

  /// Builds the map to send to Supabase.
  /// Only contains encrypted fields — no plain title/content.
  Future<Map<String, dynamic>> _buildEncryptedMap(Entry entry) async {
    final encrypted = await _enc.encryptEntry(
      title:   entry.title,
      content: entry.content,
    );
    return {
      DBColumn.titleEnc:   encrypted.titleJson,
      DBColumn.contentEnc: encrypted.contentJson,
      DBColumn.colorTag:   entry.colorTag.dbValue,
      DBColumn.wordCount:  entry.wordCount,
      DBColumn.entryDate:  entry.entryDate
          .toIso8601String()
          .substring(0, 10),
    };
  }

  /// Decrypts a single DB row into an Entry.
  Future<Entry> _decryptSingle(Map<String, dynamic> row) async {
    final titleEncRaw   = row[DBColumn.titleEnc];
    final contentEncRaw = row[DBColumn.contentEnc];

    // title_enc and content_enc may come back as Map or String
    final titleJson   = titleEncRaw   is Map
        ? _mapToJson(titleEncRaw)
        : titleEncRaw as String?;
    final contentJson = contentEncRaw is Map
        ? _mapToJson(contentEncRaw)
        : contentEncRaw as String?;

    final decrypted = await _enc.decryptEntry(
      titleJson:   titleJson,
      contentJson: contentJson,
    );

    // Inject decrypted values so Entry.fromMap can read them
    final mutable = Map<String, dynamic>.from(row);
    mutable['title']   = decrypted.title;
    mutable['content'] = decrypted.content;

    return Entry.fromMap(mutable);
  }

  /// Decrypts a list of DB rows in parallel.
  Future<List<Entry>> _decryptList(List rows) async {
    return Future.wait(
      rows.map((r) => _decryptSingle(r as Map<String, dynamic>)),
    );
  }

  /// Converts a Supabase-returned Map (JSONB parsed automatically)
  /// back to a JSON string for EncryptionService.
  String _mapToJson(Map<dynamic, dynamic> map) {
    return jsonEncode(map);
  }
}