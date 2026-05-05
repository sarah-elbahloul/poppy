import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/models/photo.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Strip Widget
//  Location: lib/core/widgets/photo_strip.dart
//
//  A horizontal scrollable strip of photo thumbnails shown
//  below the writing area — completely separate from text.
//  Supports existing (network) photos and newly picked
//  (local file) photos before they are uploaded.
// ─────────────────────────────────────────────────────────────

class PhotoStrip extends StatelessWidget {
  /// Already-saved photos (have signed URLs from Supabase).
  final List<Photo> savedPhotos;

  /// Newly picked local files not yet uploaded.
  final List<File> pendingFiles;

  /// Called when the user taps the add button.
  final VoidCallback onAddPhoto;

  /// Called when the user long-presses a saved photo to delete.
  final ValueChanged<Photo> onDeleteSavedPhoto;

  /// Called when the user long-presses a pending file to remove.
  final ValueChanged<File> onDeletePendingFile;

  /// Max number of photos per entry.
  static const int maxPhotos = 10;

  const PhotoStrip({
    super.key,
    required this.savedPhotos,
    required this.pendingFiles,
    required this.onAddPhoto,
    required this.onDeleteSavedPhoto,
    required this.onDeletePendingFile,
  });

  int get _totalCount => savedPhotos.length + pendingFiles.length;
  bool get _canAddMore => _totalCount < maxPhotos;

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(color: t.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Section label ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(
              left: kSpaceLG,
              top: kSpaceSM,
              bottom: kSpaceXS,
            ),
            child: Text(
              'Photos',
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // ── Scrollable thumbnail row ───────────────────────
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: kSpaceLG,
                right: kSpaceLG,
                bottom: kSpaceSM,
              ),
              children: [
                // Saved photos
                ...savedPhotos.map((photo) => _SavedThumb(
                  photo: photo,
                  onDelete: () => onDeleteSavedPhoto(photo),
                )),

                // Pending local files
                ...pendingFiles.map((file) => _PendingThumb(
                  file: file,
                  onDelete: () => onDeletePendingFile(file),
                )),

                // Add button — hidden when limit is reached
                if (_canAddMore) _AddButton(onTap: onAddPhoto),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saved photo thumbnail (network) ───────────────────────────

class _SavedThumb extends StatelessWidget {
  final Photo photo;
  final VoidCallback onDelete;

  const _SavedThumb({required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(right: kSpaceSM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusSM),
          color: t.surface,
          border: Border.all(color: t.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo.signedUrl != null
            ? CachedNetworkImage(
          imageUrl: photo.signedUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: t.textTertiary,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            color: t.textTertiary,
            size: 20,
          ),
        )
            : Icon(
          Icons.image_outlined,
          color: t.textTertiary,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final t = context.poppyTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('This photo will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}

// ── Pending (local file) thumbnail ────────────────────────────

class _PendingThumb extends StatelessWidget {
  final File file;
  final VoidCallback onDelete;

  const _PendingThumb({required this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onLongPress: onDelete,
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(right: kSpaceSM),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadiusSM),
              border: Border.all(color: t.accent.withOpacity(0.4), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(file, fit: BoxFit.cover),
          ),
          // Uploading indicator badge
          Positioned(
            top: 4,
            right: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add photo button ──────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusSM),
          border: Border.all(
            color: t.border,
            width: 1,
          ),
        ),
        child: Icon(
          Icons.add,
          color: t.textTertiary,
          size: 22,
        ),
      ),
    );
  }
}