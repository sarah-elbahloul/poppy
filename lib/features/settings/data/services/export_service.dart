import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/auth/data/services/encryption_service.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Export Service
// ─────────────────────────────────────────────────────────────

class ExportService {
  final _enc = EncryptionService.instance;
  final _local = LocalDbService.instance;

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

  Future<void> shareExportFile(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/json')],
      subject: 'Poppy diary export',
    );
  }

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
      throw const FormatException('Invalid Poppy export file.');
    }

    return ImportPreview(
      payload: payload,
      isEncrypted: payload['encrypted'] as bool? ?? false,
      entryCount: payload['entry_count'] as int? ?? 0,
      exportedAt: payload['exported_at'] as String? ?? '',
    );
  }

  Future<int> commitImport(ImportPreview preview) async {
    final payload = preview.payload;
    final isEncrypted = preview.isEncrypted;
    late List rawEntries;

    if (isEncrypted) {
      final encryptedBlob = payload['entries'] as String?;
      if (encryptedBlob == null) throw const FormatException('Missing data.');
      final plainText = await _enc.decryptFromJson(encryptedBlob);
      rawEntries = jsonDecode(plainText) as List;
    } else {
      rawEntries = payload['entries'] as List? ?? [];
    }

    final userId = SupabaseConfig.userId;
    int count = 0;

    for (final raw in rawEntries) {
      try {
        final map = raw as Map<String, dynamic>;
        final entryId = map['id'] as String?;

        if (entryId == null) continue;

        final existing = await _local.getEntryById(entryId);
        if (existing != null) continue;

        final encrypted = await _enc.encryptEntry(
          title: map['title'] as String? ?? '',
          content: map['content'] as String? ?? '',
        );

        await _local.insertEntry({
          DBColumn.id: entryId,
          DBColumn.userId: userId,
          DBColumn.titleEnc: encrypted.titleJson,
          DBColumn.contentEnc: encrypted.contentJson,
          DBColumn.colorTag: map['color_tag'] ?? 'stone',
          DBColumn.wordCount: map['word_count'] ?? 0,
          DBColumn.entryDate: map['entry_date'],
          DBColumn.createdAt: map['created_at'],
          DBColumn.updatedAt: map['updated_at'],
        });
        count++;
      } catch (_) {}
    }
    return count;
  }
}

class ImportPreview {
  final Map<String, dynamic> payload;
  final bool isEncrypted;
  final int entryCount;
  final String exportedAt;

  const ImportPreview({
    required this.payload,
    required this.isEncrypted,
    required this.entryCount,
    required this.exportedAt,
  });

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

class ImportCancelledException implements Exception {
  const ImportCancelledException();
}