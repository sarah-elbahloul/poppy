import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photos Service
//  Location: lib/services/photos_service.dart
//
//  Works on both web and mobile.
//  Web:    uploads raw bytes directly (no dart:io File).
//  Mobile: compresses then uploads as File.
// ─────────────────────────────────────────────────────────────

class PhotosService {
  final _client = SupabaseConfig.client;
  final _picker = ImagePicker();

  // ── Pick (mobile only — web uses ImagePicker directly) ────

  Future<File?> pickPhoto({bool fromCamera = false}) async {
    if (kIsWeb) return null; // web callers use ImagePicker directly
    final xFile = await _picker.pickImage(
      source:       fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  // ── Compress (mobile only) ────────────────────────────────

  Future<File?> _compressFile(File file) async {
    final outPath = '${file.path}_compressed.jpg';
    final result  = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, outPath,
      quality: 82, minWidth: 1080, minHeight: 1080,
    );
    return result != null ? File(result.path) : file;
  }

  // ── Upload — unified web + mobile ─────────────────────────
  // Call this from WriteScreen which already has the XFile
  // and optional bytes (bytes is non-null on web).

  Future<Photo> uploadXFile({
    required XFile      xFile,
    required Uint8List? bytes,    // non-null on web
    required String     entryId,
    required int        orderIndex,
  }) async {
    final userId      = SupabaseConfig.userId;
    final filename    = Photo.generateFilename();
    final storagePath = Photo.buildStoragePath(
      userId: userId, entryId: entryId, filename: filename,
    );

    if (kIsWeb) {
      // Web: upload bytes directly
      final uploadBytes = bytes ?? await xFile.readAsBytes();
      await _client.storage
          .from(StorageBucket.photos)
          .uploadBinary(
        storagePath,
        uploadBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
    } else {
      // Mobile: compress then upload as File
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

  // ── Legacy mobile-only upload (kept for compatibility) ────

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

  // ── Fetch photos for an entry ─────────────────────────────

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

  // ── Delete a single photo ─────────────────────────────────

  Future<void> delete(Photo photo) async {
    await _client.storage
        .from(StorageBucket.photos)
        .remove([photo.storagePath]);
    await _client
        .from(DBTable.photos)
        .delete()
        .eq(DBColumn.id, photo.id);
  }

  // ── Delete all photos for an entry ───────────────────────

  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await fetchForEntry(entryId);
    if (photos.isEmpty) return;
    final paths = photos.map((p) => p.storagePath).toList();
    log('deleting $paths');
    await _client.storage
        .from(StorageBucket.photos)
        .remove(paths);
    await _client
        .from(DBTable.photos)
        .delete()
        .eq(DBColumn.entryId, entryId);
  }

  // ── Reorder ───────────────────────────────────────────────

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