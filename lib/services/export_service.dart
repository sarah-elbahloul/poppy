import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final _client = SupabaseConfig.client;

  Future<void> exportEntries(List<Entry> entries) async {
    final payload = {
      'version':      ExportConfig.jsonVersion,
      'exported_at':  DateTime.now().toIso8601String(),
      'entry_count':  entries.length,
      'entries':      entries.map((e) => e.toExportMap()).toList(),
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes      = utf8.encode(jsonString);
    final dir        = await getTemporaryDirectory();
    final file       = File('${dir.path}/${ExportConfig.jsonFileName}');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Poppy diary export',
    );
  }

  Future<int> importEntries() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return 0;

    final file       = File(result.files.single.path!);
    final jsonString = await file.readAsString();

    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid Poppy export file.');
    }

    if (payload['version'] != ExportConfig.jsonVersion) {
      throw const FormatException('Unsupported export version.');
    }

    final rawEntries = payload['entries'] as List?;
    if (rawEntries == null || rawEntries.isEmpty) return 0;

    final userId = SupabaseConfig.userId;
    int count    = 0;

    for (final raw in rawEntries) {
      try {
        final entry = Entry.fromExportMap(
            raw as Map<String, dynamic>, userId);
        await _client.from(DBTable.entries).upsert({
          DBColumn.id:        entry.id,
          DBColumn.userId:    userId,
          DBColumn.title:     entry.title,
          DBColumn.content:   entry.content,
          DBColumn.colorTag:  entry.colorTag.dbValue,
          DBColumn.wordCount: entry.wordCount,
          DBColumn.createdAt: entry.createdAt.toIso8601String(),
          DBColumn.updatedAt: entry.updatedAt.toIso8601String(),
        });
        count++;
      } catch (_) {
        continue;
      }
    }
    return count;
  }
}