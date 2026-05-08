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
//  Also accepts .json on import for flexibility.
//
//  File structure:
//  {
//    "version":      "1.0",
//    "app":          "Poppy",
//    "exported_at":  "ISO8601",
//    "entry_count":  42,
//    "entries": [
//      {
//        "id":         "uuid",
//        "title":      "...",
//        "content":    "...",
//        "color_tag":  "poppy",
//        "word_count": 342,
//        "entry_date": "2026-05-04",
//        "created_at": "ISO8601",
//        "updated_at": "ISO8601",
//        "photo_count": 2        ← how many photos existed (not included)
//      }
//    ]
//  }
//
//  Photos are NOT exported — they would make the file enormous.
//  The photo_count field documents how many photos existed
//  so the user knows what to re-upload if they restore.
// ─────────────────────────────────────────────────────────────

class ExportService {
  final _client = SupabaseConfig.client;

  // ── Export ────────────────────────────────────────────────

  Future<void> exportEntries(List<Entry> entries) async {
    final payload = {
      'version':      ExportConfig.jsonVersion,
      'app':          'Poppy',
      'exported_at':  DateTime.now().toIso8601String(),
      'entry_count':  entries.length,
      'entries':      entries.map((e) => e.toExportMap()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes      = utf8.encode(jsonString);

    if (kIsWeb) {
      // On web, trigger a browser download
      await _webDownload(bytes, ExportConfig.poppyFileName);
    } else {
      // On mobile, write to temp dir and share
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${ExportConfig.poppyFileName}');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'Poppy diary export',
      );
    }
  }

  // Web download via anchor element trick
  Future<void> _webDownload(List<int> bytes, String filename) async {
    // We use share_plus on web too — it triggers a download
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name:     filename,
      mimeType: 'application/octet-stream',
    );
    await Share.shareXFiles([xFile], subject: 'Poppy diary export');
  }

  // ── Import ────────────────────────────────────────────────

  /// Returns the number of entries successfully imported.
  Future<int> importEntries() async {
    // Accept both .poppy and .json
    final result = await FilePicker.platform.pickFiles(
      type:               FileType.custom,
      allowedExtensions:  ['poppy', 'json'],
      withData:           true, // needed for web (returns bytes directly)
    );
    if (result == null || result.files.isEmpty) return 0;

    final pickedFile = result.files.single;

    // Get the raw bytes — works on both web and mobile
    late String jsonString;
    if (kIsWeb) {
      // On web, bytes are available directly
      if (pickedFile.bytes == null) return 0;
      jsonString = utf8.decode(pickedFile.bytes!);
    } else {
      // On mobile, read from path
      if (pickedFile.path == null) return 0;
      jsonString = await File(pickedFile.path!).readAsString();
    }

    // Parse
    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
          'Could not read this file. Make sure it is a valid Poppy export.');
    }

    // Version check
    final app     = payload['app'] as String?;
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

    final userId = SupabaseConfig.userId;
    int count    = 0;

    for (final raw in rawEntries) {
      try {
        final entry = Entry.fromExportMap(
            raw as Map<String, dynamic>, userId);

        // Upsert — safe to re-import the same file
        await _client.from(DBTable.entries).upsert({
          DBColumn.id:        entry.id,
          DBColumn.userId:    userId,
          DBColumn.title:     entry.title,
          DBColumn.content:   entry.content,
          DBColumn.colorTag:  entry.colorTag.dbValue,
          DBColumn.wordCount: entry.wordCount,
          DBColumn.entryDate: entry.entryDate
              .toIso8601String()
              .substring(0, 10),
          DBColumn.createdAt: entry.createdAt.toIso8601String(),
          DBColumn.updatedAt: entry.updatedAt.toIso8601String(),
        });
        count++;
      } catch (_) {
        // Skip malformed entries and continue
        continue;
      }
    }
    return count;
  }
}