import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/photo.dart';
import 'package:poppy/services/local_db_service.dart';
import 'package:poppy/services/sync_service.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photos Service
//  Location: lib/services/photos_service.dart
// ─────────────────────────────────────────────────────────────

/// Manages photo attachments with an offline-first approach.
/// 
/// This service handles:
/// - Picking images from camera or gallery.
/// - Compressing images locally to save space and bandwidth.
/// - Saving photo metadata to the local database.
/// - Triggering background synchronization for cloud storage.
class PhotosService {
  final _local = LocalDbService.instance;
  final _sync = SyncService.instance;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  // ─────────────────────────────────────────────────────────────
  //  Image Picking
  // ─────────────────────────────────────────────────────────────

  /// Opens the system image picker.
  Future<File?> pickPhoto({bool fromCamera = false}) async {
    if (kIsWeb) return null;
    final xFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  // ─────────────────────────────────────────────────────────────
  //  Compression
  // ─────────────────────────────────────────────────────────────

  /// Compresses the image file to a maximum dimension of 1080px and 82% quality.
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

  // ─────────────────────────────────────────────────────────────
  //  Persistence
  // ─────────────────────────────────────────────────────────────

  /// Backward compatible method for UI callers.
  /// 
  /// Effectively wraps [savePhoto] while accepting common parameters from older iterations.
  Future<Photo> uploadXFile({
    required dynamic xFile, // Accepts XFile or File
    required Uint8List? bytes,
    required String entryId,
    required int orderIndex,
  }) async {
    final file = File(xFile.path);
    return savePhoto(file: file, entryId: entryId);
  }

  /// Saves a photo locally and enqueues it for upload.
  /// 
  /// The process:
  /// 1. Compresses the file.
  /// 2. Records the local file path and metadata in SQLite.
  /// 3. Triggers the [SyncService] to handle cloud upload in the background.
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

  // ─────────────────────────────────────────────────────────────
  //  Retrieval & Cleanup
  // ─────────────────────────────────────────────────────────────

  /// Fetches all photos associated with a specific entry.
  /// 
  /// For uploaded photos, it fetches temporary signed URLs from the cloud storage
  /// to allow secure viewing.
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

  /// Marks a photo as deleted locally, which will trigger cloud deletion during next sync.
  Future<void> delete(dynamic photoOrId) async {
    final id = photoOrId is Photo ? photoOrId.id : photoOrId as String;
    await _local.markPhotoDeleted(id);
    _sync.syncNow();
  }

  /// Batch marks all photos of an entry as deleted.
  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await _local.getPhotosForEntry(entryId);
    for (final row in photos) {
      await _local.markPhotoDeleted(row[DBColumn.id] as String);
    }
    _sync.syncNow();
  }
}
