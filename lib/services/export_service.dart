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

/// Handles data portability for journal entries, supporting both plain and encrypted formats.
///
/// **Export Modes:**
/// - **Plain**: Entries are decrypted and stored as human-readable JSON.
/// - **Encrypted**: The entire entries array is encrypted as a single blob using the
///   user's Data Key. Importing this requires the same account and password.
///
/// **File Format:**
/// The export file contains a cleartext header with metadata and an `entries` field
/// containing either a JSON array (plain) or an encrypted string (encrypted).
class ExportService {
  final _client = SupabaseConfig.client;
  final _enc = EncryptionService.instance;

  /// Exports a list of [entries] to a JSON file.
  ///
  /// If [encrypted] is true, the data is secured with the user's encryption key.
  /// Returns the file path where the export was saved, or null on Web.
  Future<String?> exportEntries(
    List<Entry> entries, {
    bool encrypted = true,
  }) async {
    final entriesJson = entries.map((e) => e.toExportMap()).toList();

    Map<String, dynamic> payload;

    if (encrypted) {
      final plainText = jsonEncode(entriesJson);
      final encryptedBlob = await _enc.encryptToJson(plainText);

      payload = {
        'version': ExportConfig.jsonVersion,
        'app': 'Poppy',
        'exported_at': DateTime.now().toIso8601String(),
        'entry_count': entries.length,
        'encrypted': true,
        'entries': encryptedBlob,
      };
    } else {
      payload = {
        'version': ExportConfig.jsonVersion,
        'app': 'Poppy',
        'exported_at': DateTime.now().toIso8601String(),
        'entry_count': entries.length,
        'encrypted': false,
        'entries': entriesJson,
      };
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = utf8.encode(jsonString);
    final filename = ExportConfig.fileName();

    return _saveToDownloads(bytes, filename);
  }

  /// Internal helper to save bytes to platform-appropriate storage.
  Future<String?> _saveToDownloads(List<int> bytes, String filename) async {
    if (kIsWeb) {
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: filename,
        mimeType: 'application/json',
      );
      await Share.shareXFiles([xFile], subject: 'Poppy diary export');
      return null;
    }

    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  /// Opens the system share sheet for a previously saved export file.
  Future<void> shareExportFile(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/json')],
      subject: 'Poppy diary export',
    );
  }

  /// Initiates the import process by allowing the user to pick an export file.
  ///
  /// Returns an [ImportPreview] containing metadata from the file header.
  /// Throws [ImportCancelledException] if the picker is dismissed.
  Future<ImportPreview> previewImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
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

    final isEncrypted = payload['encrypted'] as bool? ?? false;
    final entryCount = payload['entry_count'] as int? ?? 0;
    final exportedAt = payload['exported_at'] as String? ?? '';

    return ImportPreview(
      payload: payload,
      isEncrypted: isEncrypted,
      entryCount: entryCount,
      exportedAt: exportedAt,
    );
  }

  /// Persists the entries from a validated [preview] to the database.
  ///
  /// Decrypts the data if necessary using the current user's session keys.
  /// Returns the number of entries successfully imported.
  Future<int> commitImport(ImportPreview preview) async {
    final payload = preview.payload;
    final isEncrypted = preview.isEncrypted;
    late List rawEntries;

    if (isEncrypted) {
      final encryptedBlob = payload['entries'] as String?;
      if (encryptedBlob == null) {
        throw const FormatException('Encrypted export is missing data.');
      }

      final plainText = await _enc.decryptFromJson(encryptedBlob);
      if (plainText.isEmpty) {
        throw const FormatException(
            'Could not decrypt this export. '
            'Make sure you are signed in with the same account '
            'and password that created this export.');
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

    final userId = SupabaseConfig.userId;
    int count = 0;

    for (final raw in rawEntries) {
      try {
        final map = raw as Map<String, dynamic>;

        final entryId = map['id'] as String?;
        if (entryId == null || entryId.isEmpty) continue;

        final title = map['title'] as String? ?? '';
        final content = map['content'] as String? ?? '';
        final colorTag = map['color_tag'] as String? ?? 'stone';
        final wordCount = map['word_count'] as int? ?? 0;
        final entryDate = map['entry_date'] as String? ??
            (map['created_at'] as String?)?.substring(0, 10) ??
            DateTime.now().toIso8601String().substring(0, 10);
        final createdAt = map['created_at'] as String? ?? DateTime.now().toIso8601String();
        final updatedAt = map['updated_at'] as String? ?? DateTime.now().toIso8601String();

        final encrypted = await _enc.encryptEntry(
          title: title,
          content: content,
        );

        await _client.from(DBTable.entries).upsert(
          {
            DBColumn.id: entryId,
            DBColumn.userId: userId,
            DBColumn.titleEnc: encrypted.titleJson,
            DBColumn.contentEnc: encrypted.contentJson,
            DBColumn.colorTag: colorTag,
            DBColumn.wordCount: wordCount,
            DBColumn.entryDate: entryDate,
            DBColumn.createdAt: createdAt,
            DBColumn.updatedAt: updatedAt,
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

/// Metadata extracted from an export file before entries are committed.
class ImportPreview {
  /// The full parsed JSON payload from the export file.
  final Map<String, dynamic> payload;

  /// Whether the file's entry data is encrypted.
  final bool isEncrypted;

  /// The total number of entries reported in the file header.
  final int entryCount;

  /// The ISO8601 timestamp when the file was exported.
  final String exportedAt;

  const ImportPreview({
    required this.payload,
    required this.isEncrypted,
    required this.entryCount,
    required this.exportedAt,
  });

  /// Returns a human-readable formatted string of the export date.
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

/// Exception thrown when an import operation is manually cancelled.
class ImportCancelledException implements Exception {
  const ImportCancelledException();
}
