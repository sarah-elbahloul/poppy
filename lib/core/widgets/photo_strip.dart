import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/models/photo.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Strip Widget
//  Location: lib/core/widgets/photo_strip.dart
// ─────────────────────────────────────────────────────────────

class PhotoStrip extends StatelessWidget {
  final List<Photo> savedPhotos;
  final List<File>  pendingFiles;
  final VoidCallback onAddPhoto;
  final ValueChanged<Photo> onDeleteSavedPhoto;
  final ValueChanged<File>  onDeletePendingFile;

  static const int maxPhotos = 10;

  const PhotoStrip({
    super.key,
    required this.savedPhotos,
    required this.pendingFiles,
    required this.onAddPhoto,
    required this.onDeleteSavedPhoto,
    required this.onDeletePendingFile,
  });

  int  get _totalCount => savedPhotos.length + pendingFiles.length;
  bool get _canAddMore => _totalCount < maxPhotos;

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0,0,0,AppSpacing.sm),
            child: Text(
              'Photos',
              style: AppTextStyles.meta(t.textTertiary),
            ),
          ),
          SizedBox(
            height: AppComponentSize.photoStripHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...savedPhotos.map((p) => _SavedThumb(
                  photo:    p,
                  onDelete: () => onDeleteSavedPhoto(p),
                )),
                ...pendingFiles.map((f) => _PendingThumb(
                  file:     f,
                  onDelete: () => onDeletePendingFile(f),
                )),
                if (_canAddMore) _AddButton(onTap: onAddPhoto),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saved photo thumbnail ──────────────────────────────────────

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
        width:  AppComponentSize.photoThumbSize,
        height: AppComponentSize.photoThumbSize,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color:  t.surface,
          border: Border.all(color: t.border, width: AppStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo.signedUrl != null
            ? CachedNetworkImage(
          imageUrl:    photo.signedUrl!,
          fit:         BoxFit.cover,
          placeholder: (_, __) => Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5, color: t.textTertiary,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Icon(
            AppIcons.imageBroken,
            color: t.textTertiary,
            size:  AppIconSize.sm,
          ),
        )
            : Icon(AppIcons.photo, color: t.textTertiary,
            size: AppIconSize.sm),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final t = context.poppyTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Remove photo?'),
        content: const Text('This photo will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}

// ── Pending thumbnail ──────────────────────────────────────────

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
            width:  AppComponentSize.photoThumbSize,
            height: AppComponentSize.photoThumbSize,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: t.accent.withOpacity(0.4),
                width: AppStroke.thin,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(file, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4, right: 12,
            child: Container(
              width: 8, height: 8,
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

// ── Add button ─────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  AppComponentSize.photoThumbSize,
        height: AppComponentSize.photoThumbSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.border, width: AppStroke.thin),
        ),
        child: Icon(AppIcons.add, color: t.textTertiary,
            size: AppIconSize.md),
      ),
    );
  }
}