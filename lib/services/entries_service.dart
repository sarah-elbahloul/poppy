import 'dart:convert';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Service
//  Location: lib/services/entries_service.dart
//
//  Write path: plaintext → encrypt → store title_enc/content_enc
//  Read path:  fetch title_enc/content_enc → decrypt → Entry
//  Search:     client-side after decryption (content is encrypted)
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

  // ── Key rotation (called on password change) ──────────────
  // Decrypts every entry with the current (old) key, then
  // re-encrypts with the new key and updates the row.
  // Called BEFORE the password is changed in Supabase so the
  // old key is still active during re-encryption.

  Future<void> rotateEncryptionKey({
    required EncryptionService oldKeyService,
    required EncryptionService newKeyService,
  }) async {
    final response = await _client
        .from(DBTable.entries)
        .select()
        .eq(DBColumn.userId, SupabaseConfig.userId);

    final rows = response as List;

    for (final row in rows) {
      final r = row as Map<String, dynamic>;

      // Decrypt with old key
      final titleJson   = _toJsonString(r[DBColumn.titleEnc]);
      final contentJson = _toJsonString(r[DBColumn.contentEnc]);

      final decrypted = await oldKeyService.decryptEntry(
        titleJson:   titleJson,
        contentJson: contentJson,
      );

      // Re-encrypt with new key
      final reEncrypted = await newKeyService.encryptEntry(
        title:   decrypted.title,
        content: decrypted.content,
      );

      // Update row in DB
      await _client
          .from(DBTable.entries)
          .update({
        DBColumn.titleEnc:   reEncrypted.titleJson,
        DBColumn.contentEnc: reEncrypted.contentJson,
        DBColumn.updatedAt:  DateTime.now().toIso8601String(),
      })
          .eq(DBColumn.id,     r[DBColumn.id] as String)
          .eq(DBColumn.userId, SupabaseConfig.userId);
    }
  }

  // ── Encryption helpers ────────────────────────────────────

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

  Future<Entry> _decryptSingle(Map<String, dynamic> row) async {
    final titleJson   = _toJsonString(row[DBColumn.titleEnc]);
    final contentJson = _toJsonString(row[DBColumn.contentEnc]);

    final decrypted = await _enc.decryptEntry(
      titleJson:   titleJson,
      contentJson: contentJson,
    );

    final mutable = Map<String, dynamic>.from(row);
    mutable['title']   = decrypted.title;
    mutable['content'] = decrypted.content;

    return Entry.fromMap(mutable);
  }

  Future<List<Entry>> _decryptList(List rows) async {
    return Future.wait(
      rows.map((r) => _decryptSingle(r as Map<String, dynamic>)),
    );
  }

  // Supabase returns JSONB columns as Map<dynamic,dynamic>.
  // Convert back to JSON string for EncryptionService.
  String? _toJsonString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map)    return jsonEncode(value);
    return null;
  }
}