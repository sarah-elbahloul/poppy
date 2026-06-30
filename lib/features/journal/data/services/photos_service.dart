import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/core/services/supabase_client.dart';
import 'package:poppy/features/journal/data/models/photo.dart';
import 'package:poppy/core/services/local_db_service.dart';
import 'package:poppy/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photos Service
//  Location: lib/features/journal/data/services/photos_service.dart
// ─────────────────────────────────────────────────────────────

class PhotosService {
  final _local = LocalDbService.instance;
  final _sync = SyncService.instance;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<File?> pickPhoto({bool fromCamera = false}) async {
    if (kIsWeb) return null;
    final xFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  Future<File?> _compressFile(File file) async {
    final outPath = '${file.path}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 82,
      minWidth: 1080,
      minHeight: 1080,
    );
    return result != null ? File(result.path) : file;
  }

  Future<Photo> uploadXFile({
    required dynamic xFile,
    required Uint8List? bytes,
    required String entryId,
    required int orderIndex,
  }) async {
    final file = File(xFile.path);
    return savePhoto(file: file, entryId: entryId);
  }

  Future<Photo> savePhoto({
    required File file,
    required String entryId,
  }) async {
    final userId = SupabaseConfig.userId;
    final id = _uuid.v4();
    
    final compressed = await _compressFile(file) ?? file;
    
    final photoMap = {
      DBColumn.id: id,
      DBColumn.entryId: entryId,
      DBColumn.userId: userId,
      DBColumn.localPath: compressed.path,
      DBColumn.uploaded: 0,
      DBColumn.createdAt: DateTime.now().toUtc().toIso8601String(),
    };

    await _local.insertPhoto(photoMap);
    _sync.syncNow(); 

    return Photo.fromMap(photoMap);
  }

  Future<List<Photo>> fetchForEntry(String entryId) async {
    final rows = await _local.getPhotosForEntry(entryId);
    final photos = rows.map((m) => Photo.fromMap(m)).toList();

    return await Future.wait(
      photos.map((photo) async {
        if (photo.uploaded && photo.storagePath != null) {
          try {
            final url = await SupabaseConfig.getSignedUrl(
              StorageBucket.photos,
              photo.storagePath!,
            );
            return photo.copyWith(signedUrl: url);
          } catch (_) {
            return photo;
          }
        }
        return photo;
      }),
    );
  }

  Future<void> delete(dynamic photoOrId) async {
    final id = photoOrId is Photo ? photoOrId.id : photoOrId as String;
    await _local.markPhotoDeleted(id);
    _sync.syncNow();
  }

  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await _local.getPhotosForEntry(entryId);
    for (final row in photos) {
      await _local.markPhotoDeleted(row[DBColumn.id] as String);
    }
    _sync.syncNow();
  }
}
