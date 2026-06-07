import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages photo attachments for journal entries, including picking, compression,
/// storage, and metadata management.
class PhotosService {
  final _client = SupabaseConfig.client;
  final _picker = ImagePicker();

  // --- Image Picking ---

  /// Launches the system image picker to select a photo from the gallery or camera.
  ///
  /// Returns a [File] representing the selected image, or null if cancelled.
  /// Note: Only supported on mobile platforms.
  Future<File?> pickPhoto({bool fromCamera = false}) async {
    if (kIsWeb) return null;
    final xFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  // --- Compression ---

  /// Compresses a [file] to reduce its size before upload.
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

  // --- Upload Operations ---

  /// Uploads an [XFile] or raw [bytes] to Supabase Storage and records its metadata.
  ///
  /// Mobile images are automatically compressed before upload.
  Future<Photo> uploadXFile({
    required XFile xFile,
    required Uint8List? bytes,
    required String entryId,
    required int orderIndex,
  }) async {
    final userId = SupabaseConfig.userId;
    final filename = Photo.generateFilename();
    final storagePath = Photo.buildStoragePath(
      userId: userId,
      entryId: entryId,
      filename: filename,
    );

    if (kIsWeb) {
      final uploadBytes = bytes ?? await xFile.readAsBytes();
      await _client.storage.from(StorageBucket.photos).uploadBinary(
            storagePath,
            uploadBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } else {
      final file = File(xFile.path);
      final compressed = await _compressFile(file) ?? file;
      await _client.storage.from(StorageBucket.photos).upload(storagePath, compressed);
    }

    final map = {
      DBColumn.entryId: entryId,
      DBColumn.userId: userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex: orderIndex,
    };
    final response = await _client.from(DBTable.photos).insert(map).select().single();
    return Photo.fromMap(response as Map<String, dynamic>);
  }

  /// Uploads a standard [File] to storage (Mobile only).
  Future<Photo> upload({
    required File file,
    required String entryId,
    required int orderIndex,
  }) async {
    final userId = SupabaseConfig.userId;
    final filename = Photo.generateFilename();
    final storagePath = Photo.buildStoragePath(
      userId: userId,
      entryId: entryId,
      filename: filename,
    );
    final compressed = await _compressFile(file) ?? file;
    await _client.storage.from(StorageBucket.photos).upload(storagePath, compressed);

    final map = {
      DBColumn.entryId: entryId,
      DBColumn.userId: userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex: orderIndex,
    };
    final response = await _client.from(DBTable.photos).insert(map).select().single();
    return Photo.fromMap(response as Map<String, dynamic>);
  }

  // --- Retrieval & Cleanup ---

  /// Retrieves photo records for a specific [entryId], including temporary signed URLs for display.
  Future<List<Photo>> fetchForEntry(String entryId) async {
    final response = await _client
        .from(DBTable.photos)
        .select()
        .eq(DBColumn.entryId, entryId)
        .order(DBColumn.orderIndex, ascending: true);

    final photos = (response as List).map((map) => Photo.fromMap(map as Map<String, dynamic>)).toList();

    return await Future.wait(
      photos.map((photo) async {
        try {
          final url = await SupabaseConfig.getSignedUrl(
            StorageBucket.photos,
            photo.storagePath,
          );
          return photo.copyWith(signedUrl: url);
        } catch (_) {
          return photo;
        }
      }),
    );
  }

  /// Deletes a specific [photo] from both storage and the metadata database.
  Future<void> delete(Photo photo) async {
    await _client.storage.from(StorageBucket.photos).remove([photo.storagePath]);
    await _client.from(DBTable.photos).delete().eq(DBColumn.id, photo.id);
  }

  /// Permanently removes all photos associated with a specific [entryId].
  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await fetchForEntry(entryId);
    if (photos.isEmpty) return;
    final paths = photos.map((p) => p.storagePath).toList();
    await _client.storage.from(StorageBucket.photos).remove(paths);
    await _client.from(DBTable.photos).delete().eq(DBColumn.entryId, entryId);
  }

  /// Updates the persistence layer with a new display order for the provided [photos].
  Future<void> reorder(List<Photo> photos) async {
    await Future.wait(
      photos.asMap().entries.map((entry) async {
        await _client
            .from(DBTable.photos)
            .update({DBColumn.orderIndex: entry.key}).eq(DBColumn.id, entry.value.id);
      }),
    );
  }
}
