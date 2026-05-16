import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────
//  POPPY — Export / Import Service
//  Location: lib/services/export_service.dart
//
//  Export modes:
//    Plain    → entries decrypted in file, anyone can read it
//    Encrypted → entire entries array encrypted as one blob,
//                requires the same password to import
//
//  File header always readable (not encrypted):
//  {
//    "version":    "1.0",
//    "app":        "Poppy",
//    "exported_at": "...",
//    "entry_count": 42,
//    "encrypted":  true | false,
//    "entries":    [ ... ] | "<encrypted blob>"
//  }
//
//  Import:
//  - Detects encrypted flag
//  - If encrypted, decrypts blob using current key before parsing
//  - After import, caller must call fetchEntries() to refresh
// ─────────────────────────────────────────────────────────────

class ExportService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  // ── Export ────────────────────────────────────────────────

  /// [encrypted] = true  → secure export (blob encrypted with user key)
  /// [encrypted] = false → plain export (human-readable JSON)
  Future<void> exportEntries(
      List<Entry> entries, {
        bool encrypted = true,
      }) async {
    // Entries are already decrypted in memory — use toExportMap()
    final entriesJson = entries.map((e) => e.toExportMap()).toList();

    Map<String, dynamic> payload;

    if (encrypted) {
      // Encrypt the entire entries array as one blob
      final plainText  = jsonEncode(entriesJson);
      final encryptedBlob = await _enc.encryptToJson(plainText);

      payload = {
        'version':     ExportConfig.jsonVersion,
        'app':         'Poppy',
        'exported_at': DateTime.now().toIso8601String(),
        'entry_count': entries.length,
        'encrypted':   true,
        'entries':     encryptedBlob, // single encrypted string
      };
    } else {
      payload = {
        'version':     ExportConfig.jsonVersion,
        'app':         'Poppy',
        'exported_at': DateTime.now().toIso8601String(),
        'entry_count': entries.length,
        'encrypted':   false,
        'entries':     entriesJson,
      };
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes      = utf8.encode(jsonString);

    await _share(bytes);
  }

  Future<void> _share(List<int> bytes) async {
    if (kIsWeb) {
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name:     ExportConfig.poppyFileName,
        mimeType: 'application/octet-stream',
      );
      await Share.shareXFiles([xFile], subject: 'Poppy diary export');
    } else {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${ExportConfig.poppyFileName}');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'Poppy diary export',
      );
    }
  }

  // ── Import ────────────────────────────────────────────────
  // Returns the number of entries successfully imported.
  // Caller MUST call entriesProvider.fetchEntries() after this.

  Future<int> importEntries() async {
    final result = await FilePicker.platform.pickFiles(
      type:              FileType.custom,
      allowedExtensions: ['poppy', 'json'],
      withData:          true,
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

    // ── Parse outer envelope ──────────────────────────────
    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
          'Could not read this file. Make sure it is a valid Poppy export.');
    }

    if (payload['app'] != 'Poppy') {
      throw const FormatException(
          'This does not appear to be a Poppy export file.');
    }
    if (payload['version'] != ExportConfig.jsonVersion) {
      throw const FormatException(
          'This export was made with a different version of Poppy.');
    }

    // ── Decrypt if encrypted export ───────────────────────
    final isEncrypted = payload['encrypted'] as bool? ?? false;
    late List rawEntries;

    if (isEncrypted) {
      final encryptedBlob = payload['entries'] as String?;
      if (encryptedBlob == null) {
        throw const FormatException('Encrypted export is missing data.');
      }
      // Decrypt blob using the current user's key
      final plainText = await _enc.decryptFromJson(encryptedBlob);
      if (plainText.isEmpty) {
        throw const FormatException(
            'Could not decrypt this export. '
                'Make sure you are signed in with the same account '
                'that created this export.');
      }
      try {
        rawEntries = jsonDecode(plainText) as List;
      } catch (_) {
        throw const FormatException(
            'Decrypted data is corrupted. The file may be damaged.');
      }
    } else {
      // Plain export — entries is already a list
      rawEntries = payload['entries'] as List? ?? [];
    }

    if (rawEntries.isEmpty) return 0;

    // ── Upsert entries ────────────────────────────────────
    final userId = SupabaseConfig.userId;
    int count    = 0;

    for (final raw in rawEntries) {
      try {
        final map = raw as Map<String, dynamic>;

        final entryId = map['id'] as String?;
        if (entryId == null || entryId.isEmpty) continue;

        // Parse plain values from export map
        final title     = map['title']     as String? ?? '';
        final content   = map['content']   as String? ?? '';
        final colorTag  = map['color_tag'] as String? ?? 'stone';
        final wordCount = map['word_count'] as int?   ?? 0;
        final entryDate = map['entry_date'] as String?
            ?? (map['created_at'] as String?)?.substring(0, 10)
            ?? DateTime.now().toIso8601String().substring(0, 10);
        final createdAt = map['created_at'] as String?
            ?? DateTime.now().toIso8601String();
        final updatedAt = map['updated_at'] as String?
            ?? DateTime.now().toIso8601String();

        // Encrypt before storing
        final encrypted = await _enc.encryptEntry(
          title:   title,
          content: content,
        );

        await _client.from(DBTable.entries).upsert(
          {
            DBColumn.id:         entryId,
            DBColumn.userId:     userId,
            DBColumn.titleEnc:   encrypted.titleJson,
            DBColumn.contentEnc: encrypted.contentJson,
            DBColumn.colorTag:   colorTag,
            DBColumn.wordCount:  wordCount,
            DBColumn.entryDate:  entryDate,
            DBColumn.createdAt:  createdAt,
            DBColumn.updatedAt:  updatedAt,
          },
          onConflict: DBColumn.id,
        );
        count++;
      } catch (_) {
        continue;
      }
    }
    return count;
  }
}