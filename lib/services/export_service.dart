import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Export / Import Service
//  Location: lib/services/export_service.dart
//
//  Export modes:
//    Plain     → entries decrypted in file, anyone can read it
//    Encrypted → entire entries array encrypted as one blob,
//                requires the SAME account password to import
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
//  NOTE: user_id is intentionally NOT stored in the export file.
//  Cross-account detection relies solely on decryption failure,
//  which already returns an empty string on failure.  Omitting
//  user_id avoids leaking which Supabase account created the file.
//
//  Files are saved directly to the Downloads folder (Android) or the
//  app Documents directory (iOS, visible in Files app).  A share sheet
//  is offered as a secondary option.
//
//  Filenames are timestamped so successive exports never clobber each
//  other: poppy_2026-05-29_14-30.json
// ─────────────────────────────────────────────────────────────

class ExportService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  // ── Export ────────────────────────────────────────────────

  /// [encrypted] = true  → secure export (blob encrypted with user key)
  /// [encrypted] = false → plain export (human-readable JSON)
  ///
  /// Returns the path where the file was saved (for snackbar feedback),
  /// or null if the operation was cancelled / web share was used.
  Future<String?> exportEntries(
      List<Entry> entries, {
        bool encrypted = true,
      }) async {
    // Entries are already decrypted in memory — use toExportMap()
    final entriesJson = entries.map((e) => e.toExportMap()).toList();

    Map<String, dynamic> payload;

    if (encrypted) {
      // Encrypt the entire entries array as one blob.
      // user_id is intentionally omitted — see file header comment.
      final plainText     = jsonEncode(entriesJson);
      final encryptedBlob = await _enc.encryptToJson(plainText);

      payload = {
        'version':     ExportConfig.jsonVersion,
        'app':         'Poppy',
        'exported_at': DateTime.now().toIso8601String(),
        'entry_count': entries.length,
        'encrypted':   true,
        'entries':     encryptedBlob,
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
    final filename   = ExportConfig.fileName();

    return _saveToDownloads(bytes, filename);
  }

  /// Saves to the Downloads folder (Android) or app Documents (iOS).
  /// On web, falls back to a share sheet.
  /// Returns the saved path, or null on web / cancellation.
  Future<String?> _saveToDownloads(List<int> bytes, String filename) async {
    if (kIsWeb) {
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name:     filename,
        mimeType: 'application/json',
      );
      await Share.shareXFiles([xFile], subject: 'Poppy diary export');
      return null;
    }

    if (Platform.isAndroid) {
      // Android 10+ uses scoped storage — /storage/emulated/0/Download is
      // the stable path for files the user can find in the Files app.
      // No WRITE_EXTERNAL_STORAGE permission is needed for this path on
      // Android 10+ when targeting API 29+.
      final dir  = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } else {
      // iOS: save to app Documents folder (visible in Files → On My iPhone → Poppy)
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  /// Opens a share sheet for the given saved file.
  /// Call this if the user taps "Share" from the post-export snackbar.
  Future<void> shareExportFile(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/json')],
      subject: 'Poppy diary export',
    );
  }

  // ── Import ────────────────────────────────────────────────
  //
  // Returns an [ImportPreview] with metadata from the file header
  // so the caller can show a confirmation dialog before committing.
  //
  // Cross-account detection:
  //   user_id is no longer stored in the export.  If decryption fails
  //   (returns empty string), we throw a FormatException with a clear
  //   "wrong account or changed password" message.  This is functionally
  //   identical to the previous user_id check but without leaking the uid.

  /// Step 1 — read the file and return a preview (no entries written yet).
  Future<ImportPreview> previewImport() async {
    final result = await FilePicker.platform.pickFiles(
      // FileType.custom with allowedExtensions blocks .json on some Android
      // versions.  Use FileType.any and validate contents ourselves.
      type:     FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw const ImportCancelledException();
    }

    final pickedFile = result.files.single;
    late String jsonString;

    if (kIsWeb) {
      if (pickedFile.bytes == null) throw const ImportCancelledException();
      jsonString = utf8.decode(pickedFile.bytes!);
    } else {
      if (pickedFile.path == null) throw const ImportCancelledException();
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

    final isEncrypted  = payload['encrypted']   as bool?   ?? false;
    final entryCount   = payload['entry_count']  as int?    ?? 0;
    final exportedAt   = payload['exported_at']  as String? ?? '';

    return ImportPreview(
      payload:     payload,
      isEncrypted: isEncrypted,
      entryCount:  entryCount,
      exportedAt:  exportedAt,
    );
  }

  /// Step 2 — commit the import after the user has confirmed the preview.
  /// Returns the number of entries successfully written.
  /// Caller MUST call entriesProvider.fetchEntries() after this.
  Future<int> commitImport(ImportPreview preview) async {
    final payload     = preview.payload;
    final isEncrypted = preview.isEncrypted;
    late List rawEntries;

    if (isEncrypted) {
      final encryptedBlob = payload['entries'] as String?;
      if (encryptedBlob == null) {
        throw const FormatException('Encrypted export is missing data.');
      }

      // Attempt decryption with current key.
      // Empty result → wrong account or changed password.
      final plainText = await _enc.decryptFromJson(encryptedBlob);
      if (plainText.isEmpty) {
        throw const FormatException(
            'Could not decrypt this export. '
                'Make sure you are signed in with the same account '
                'and password that created this export. '
                'If you changed your password since exporting, '
                'the file can no longer be decrypted.');
      }

      try {
        rawEntries = jsonDecode(plainText) as List;
      } catch (_) {
        throw const FormatException(
            'Decrypted data is corrupted. The file may be damaged.');
      }
    } else {
      rawEntries = payload['entries'] as List? ?? [];
    }

    if (rawEntries.isEmpty) return 0;

    // ── Upsert entries ────────────────────────────────────
    final userId = SupabaseConfig.userId;
    int   count  = 0;

    for (final raw in rawEntries) {
      try {
        final map = raw as Map<String, dynamic>;

        final entryId = map['id'] as String?;
        if (entryId == null || entryId.isEmpty) continue;

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

        // Re-encrypt with the current user's key before storing
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

// ── Supporting types ──────────────────────────────────────────

/// Metadata extracted from an export file before any entries are written.
/// Shown to the user in a confirmation dialog.
class ImportPreview {
  final Map<String, dynamic> payload;
  final bool   isEncrypted;
  final int    entryCount;
  final String exportedAt;

  const ImportPreview({
    required this.payload,
    required this.isEncrypted,
    required this.entryCount,
    required this.exportedAt,
  });

  /// Parses exportedAt into a human-readable date, e.g. "May 15, 2026".
  String get exportedAtFormatted {
    try {
      final dt = DateTime.parse(exportedAt).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return exportedAt;
    }
  }
}

/// Thrown when the user cancels the file picker (not a real error).
class ImportCancelledException implements Exception {
  const ImportCancelledException();
}