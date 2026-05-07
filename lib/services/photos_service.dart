import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/photo.dart';

class PhotosService {
  final _client = SupabaseConfig.client;
  final _picker = ImagePicker();

  Future<File?> pickPhoto({bool fromCamera = false}) async {
    final xFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  Future<File?> _compress(File file) async {
    final outPath = '${file.path}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, outPath,
      quality: 82, minWidth: 1080, minHeight: 1080,
    );
    return result != null ? File(result.path) : file;
  }

  Future<Photo> upload({
    required File file,
    required String entryId,
    required int orderIndex,
  }) async {
    final userId   = SupabaseConfig.userId;
    final filename = Photo.generateFilename();
    final storagePath = Photo.buildStoragePath(
      userId: userId, entryId: entryId, filename: filename,
    );
    final compressed = await _compress(file) ?? file;
    await _client.storage.from(StorageBucket.photos).upload(storagePath, compressed);

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
              StorageBucket.photos, photo.storagePath);
          return photo.copyWith(signedUrl: url);
        } catch (_) {
          return photo;
        }
      }),
    );
    return withUrls;
  }

  Future<void> delete(Photo photo) async {
    await _client.storage
        .from(StorageBucket.photos)
        .remove([photo.storagePath]);
    await _client
        .from(DBTable.photos)
        .delete()
        .eq(DBColumn.id, photo.id);
  }

  Future<void> deleteAllForEntry(String entryId) async {
    final photos = await fetchForEntry(entryId);
    if (photos.isEmpty) return;
    final paths = photos.map((p) => p.storagePath).toList();
    await _client.storage.from(StorageBucket.photos).remove(paths);
    await _client
        .from(DBTable.photos)
        .delete()
        .eq(DBColumn.entryId, entryId);
  }

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