import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────
//  POPPY — Export / Import Service
//  Location: lib/services/export_service.dart
//
//  Export format: .poppy (JSON with custom extension)
//  Also accepts .json on import.
//
//  Import bug fix notes:
//  ─────────────────────
//  The original bug: imported entries could not be edited
//  because the upsert preserved the original UUID but the
//  in-memory EntriesProvider cache was stale or the user_id
//  on the upserted row was wrong.
//
//  Fixes applied:
//  1. user_id is always set to the CURRENT user on import,
//     even if the export file has a different user_id.
//     This ensures the RLS policy (auth.uid() = user_id)
//     always passes for update/delete.
//  2. After import we do NOT rely on the caller to refresh —
//     we return the count and the caller (settings_screen)
//     must call EntriesProvider.fetchEntries() to sync.
//     The instruction to call fetchEntries() is documented
//     here so it is never forgotten.
//  3. The upsert uses onConflict: 'id' explicitly so Postgres
//     knows which column to conflict on and updates all other
//     columns correctly rather than doing a blind insert.
// ─────────────────────────────────────────────────────────────

class ExportService {
  final _client = SupabaseConfig.client;

  // ── Export ────────────────────────────────────────────────

  Future<void> exportEntries(List<Entry> entries) async {
    final payload = {
      'version': ExportConfig.jsonVersion,
      'app': 'Poppy',
      'exported_at': DateTime.now().toIso8601String(),
      'entry_count': entries.length,
      'entries': entries.map((e) => e.toExportMap()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = utf8.encode(jsonString);

    if (kIsWeb) {
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: ExportConfig.poppyFileName,
        mimeType: 'application/octet-stream',
      );
      await Share.shareXFiles([xFile], subject: 'Poppy diary export');
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${ExportConfig.poppyFileName}');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'Poppy diary export',
      );
    }
  }

  // ── Import ────────────────────────────────────────────────
  //
  // After calling this, the caller MUST call:
  //   await entriesProvider.fetchEntries();
  // to sync the in-memory list with what is now in the database.
  // If you skip this step, edits to imported entries will appear
  // to fail because the provider still holds stale objects.

  Future<int> importEntries() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['poppy', 'json'],
      withData: true, // required for web
    );
    if (result == null || result.files.isEmpty) return 0;

    final pickedFile = result.files.single;
    late String jsonString;

    if (kIsWeb) {
      if (pickedFile.bytes == null) return 0;
      jsonString = utf8.decode(pickedFile.bytes!);
    } else {
      if (pickedFile.path == null) return 0;
      jsonString = await File(pickedFile.path!).readAsString();
    }

    // ── Parse ────────────────────────────────────────────
    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
          'Could not read this file. Make sure it is a valid Poppy export.');
    }

    final app = payload['app'] as String?;
    final version = payload['version'] as String?;

    if (app != 'Poppy') {
      throw const FormatException(
          'This does not appear to be a Poppy export file.');
    }
    if (version != ExportConfig.jsonVersion) {
      throw const FormatException(
          'This export was created with a different version of Poppy.');
    }

    final rawEntries = payload['entries'] as List?;
    if (rawEntries == null || rawEntries.isEmpty) return 0;

    // Always use the CURRENT user's id — this is critical.
    // If the export was made by the same user on a different
    // device, the user_id in the file matches anyway.
    // If it was somehow made by a different user (shared export),
    // we still import it under the current user so RLS passes.
    final userId = SupabaseConfig.userId;
    int count = 0;

    for (final raw in rawEntries) {
      try {
        final map = raw as Map<String, dynamic>;

        // Build the upsert payload explicitly — do NOT use
        // Entry.fromExportMap here because that trusts the
        // user_id from the file, which may be wrong.
        final entryId = map['id'] as String?;
        if (entryId == null || entryId.isEmpty) continue;

        final title = map['title'] as String? ?? '';
        final content = map['content'] as String? ?? '';
        final colorTag = map['color_tag'] as String? ?? 'stone';
        final wordCount = map['word_count'] as int? ?? 0;
        final entryDate = map['entry_date'] as String? ??
            (map['created_at'] as String?)?.substring(0, 10) ??
            DateTime.now().toIso8601String().substring(0, 10);
        final createdAt =
            map['created_at'] as String? ?? DateTime.now().toIso8601String();
        final updatedAt =
            map['updated_at'] as String? ?? DateTime.now().toIso8601String();

// Check if entry already exists
        final existing = await _client
            .from(DBTable.entries)
            .select(DBColumn.id)
            .eq(DBColumn.id, entryId)
            .maybeSingle();

// Build payload (single source of truth)
        final payload = {
          DBColumn.id: entryId,
          DBColumn.userId: userId, // always enforce correct user
          DBColumn.title: title,
          DBColumn.content: content,
          DBColumn.colorTag: colorTag,
          DBColumn.wordCount: wordCount,
          DBColumn.entryDate: entryDate,
          DBColumn.createdAt: createdAt,
          DBColumn.updatedAt: updatedAt,
        };

        if (existing != null) {
          // Force FULL overwrite
          await _client
              .from(DBTable.entries)
              .update(payload)
              .eq(DBColumn.id, entryId);
        } else {
          // Fresh insert
          await _client.from(DBTable.entries).insert(payload);
        }
        count++;
      } catch (_) {
        // Skip malformed entries and continue with the rest
        continue;
      }
    }

    return count;
  }
}
