import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/photo.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photos Service
// ─────────────────────────────────────────────────────────────

/// Service for handling photo-related operations.
///
/// Includes picking images from the gallery/camera, compressing them,
/// and saving them to the local database for eventual synchronization.
class PhotosService {
  final _local = LocalDbService.instance;
  final _sync = SyncService.instance;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  /// Prompts the user to pick a photo from the camera or gallery.
  ///
  /// Returns a [File] if a photo was selected, otherwise null.
  /// Note: Not supported on Web.
  Future<File?> pickPhoto({bool fromCamera = false}) async {
    if (kIsWeb) return null;
    final xFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    return xFile != null ? File(xFile.path) : null;
  }

  /// Compresses a file to reduce its size before storage or upload.
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

  /// Uploads an [XFile] and saves it as a [Photo] associated with an entry.
  ///
  /// This is a convenience wrapper around [savePhoto].
  Future<Photo> uploadXFile({
    required dynamic xFile,
    required Uint8List? bytes,
    required String entryId,
    required int orderIndex,
  }) async {
    final file = File(xFile.path);
    return savePhoto(file: file, entryId: entryId);
  }

  /// Saves a [File] as a [Photo] in the local database.
  ///
  /// Compresses the image and associates it with the specified [entryId].
  /// Triggers a background sync.
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

  /// Fetches all photos associated with a specific [entryId].
  ///
  /// Reconciles with the server to support cross-device scenarios where photos
  /// might have been uploaded from another device. For uploaded photos,
  /// generates signed URLs for remote access.
  Future<List<Photo>> fetchForEntry(String entryId) async {
    // 1. Reconcile with server to handle photos uploaded from other devices.
    try {
      final response = await SupabaseConfig.client
          .from(DBTable.photos)
          .select()
          .eq(DBColumn.entryId, entryId);

      // response is usually a List<Map<String, dynamic>>
      await _local.refreshPhotosForEntry(
        entryId,
        List<Map<String, dynamic>>.from(response as List),
      );
    } catch (e) {
      debugPrint('PhotosService: Failed to refresh photos from server: $e');
    }

    // 2. Fetch from local database (now updated with any server changes).
    final rows = await _local.getPhotosForEntry(entryId);
    final photos = rows.map((m) => Photo.fromMap(m)).toList();

    // 3. Generate signed URLs for remote access.
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

  /// Deletes a photo given either a [Photo] object or a photo ID string.
  ///
  /// Marks the photo as deleted locally and triggers a background sync.
  Future<void> delete(dynamic photoOrId) async {
    final id = photoOrId is Photo ? photoOrId.id : photoOrId as String;
    await _local.markPhotoDeleted(id);
    _sync.syncNow();
  }

  /// Deletes all photos associated with a specific [entryId].
  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await _local.getPhotosForEntry(entryId);
    for (final row in photos) {
      await _local.markPhotoDeleted(row[DBColumn.id] as String);
    }
    _sync.syncNow();
  }
}