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

/// Poppy — Photos Service
///
/// Manages the uploading, fetching, and deletion of photos associated 
/// with journal entries. Supports both web and mobile platforms.
class PhotosService {
  final _client = SupabaseConfig.client;
  final _picker = ImagePicker();

  // --- Mobile Image Picking ---

  /// Launches the system image picker for mobile devices.
  /// 
  /// Returns a [File] representing the picked image, or null if cancelled.
  Future<File?> pickPhoto({bool fromCamera = false}) async {
    if (kIsWeb) return null;
    final xFile = await _picker.pickImage(
      source:       fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  // --- Image Compression ---

  Future<File?> _compressFile(File file) async {
    final outPath = '${file.path}_compressed.jpg';
    final result  = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, outPath,
      quality: 82, minWidth: 1080, minHeight: 1080,
    );
    return result != null ? File(result.path) : file;
  }

  // --- Photo Uploads ---

  /// Uploads an [XFile] to Supabase Storage and records it in the database.
  /// 
  /// Handles both binary data (for web) and file paths (for mobile).
  /// Mobile images are compressed before upload.
  Future<Photo> uploadXFile({
    required XFile      xFile,
    required Uint8List? bytes,
    required String     entryId,
    required int        orderIndex,
  }) async {
    final userId      = SupabaseConfig.userId;
    final filename    = Photo.generateFilename();
    final storagePath = Photo.buildStoragePath(
      userId: userId, entryId: entryId, filename: filename,
    );

    if (kIsWeb) {
      final uploadBytes = bytes ?? await xFile.readAsBytes();
      await _client.storage
          .from(StorageBucket.photos)
          .uploadBinary(
        storagePath,
        uploadBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
    } else {
      final file       = File(xFile.path);
      final compressed = await _compressFile(file) ?? file;
      await _client.storage
          .from(StorageBucket.photos)
          .upload(storagePath, compressed);
    }

    final map = {
      DBColumn.entryId:     entryId,
      DBColumn.userId:      userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex:  orderIndex,
    };
    final response = await _client
        .from(DBTable.photos)
        .insert(map)
        .select()
        .single();
    return Photo.fromMap(response as Map<String, dynamic>);
  }

  /// Uploads a [File] to Supabase Storage. (Mobile only).
  Future<Photo> upload({
    required File   file,
    required String entryId,
    required int    orderIndex,
  }) async {
    final userId      = SupabaseConfig.userId;
    final filename    = Photo.generateFilename();
    final storagePath = Photo.buildStoragePath(
      userId: userId, entryId: entryId, filename: filename,
    );
    final compressed = await _compressFile(file) ?? file;
    await _client.storage
        .from(StorageBucket.photos)
        .upload(storagePath, compressed);

    final map = {
      DBColumn.entryId:     entryId,
      DBColumn.userId:      userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex:  orderIndex,
    };
    final response = await _client
        .from(DBTable.photos)
        .insert(map)
        .select()
        .single();
    return Photo.fromMap(response as Map<String, dynamic>);
  }

  // --- Retrieval & Deletion ---

  /// Fetches all photos for a given entry ID, including temporary signed URLs.
  Future<List<Photo>> fetchForEntry(String entryId) async {
    final response = await _client
        .from(DBTable.photos)
        .select()
        .eq(DBColumn.entryId, entryId)
        .order(DBColumn.orderIndex, ascending: true);

    final photos = (response as List)
        .map((map) => Photo.fromMap(map as Map<String, dynamic>))
        .toList();

    final withUrls = await Future.wait(
      photos.map((photo) async {
        try {
          final url = await SupabaseConfig.getSignedUrl(
            StorageBucket.photos, photo.storagePath,
          );
          return photo.copyWith(signedUrl: url);
        } catch (_) {
          return photo;
        }
      }),
    );
    return withUrls;
  }

  /// Deletes a photo from both storage and the database.
  Future<void> delete(Photo photo) async {
    await _client.storage
        .from(StorageBucket.photos)
        .remove([photo.storagePath]);
    await _client
        .from(DBTable.photos)
        .delete()
        .eq(DBColumn.id, photo.id);
  }

  /// Deletes all photos associated with a specific entry.
  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await fetchForEntry(entryId);
    if (photos.isEmpty) return;
    final paths = photos.map((p) => p.storagePath).toList();
    log('Deleting photos: $paths');
    await _client.storage
        .from(StorageBucket.photos)
        .remove(paths);
    await _client
        .from(DBTable.photos)
        .delete()
        .eq(DBColumn.entryId, entryId);
  }

  /// Updates the order of photos in the database.
  Future<void> reorder(List<Photo> photos) async {
    await Future.wait(
      photos.asMap().entries.map((entry) async {
        await _client
            .from(DBTable.photos)
            .update({DBColumn.orderIndex: entry.key})
            .eq(DBColumn.id, entry.value.id);
      }),
    );
  }
}
