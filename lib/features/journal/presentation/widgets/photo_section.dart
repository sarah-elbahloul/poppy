import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/presentation/widgets/photo_full_viewer.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Section Widget
// ─────────────────────────────────────────────────────────────

/// Represents a photo that has been picked but not yet saved to the entry.
class PendingPhoto {
  final XFile xFile;
  final Uint8List? bytes;

  const PendingPhoto({required this.xFile, this.bytes});
}

/// Callback types for photo section actions.
typedef OnAddPhoto = Future<void> Function();
typedef OnDeleteSavedPhoto = void Function(dynamic photo);
typedef OnDeletePendingPhoto = void Function(PendingPhoto photo);

/// A collapsible section for managing photos attached to a journal entry.
class PhotoSection extends StatelessWidget {
  final List<dynamic> savedPhotos;
  final List<PendingPhoto> pendingPhotos;
  final bool isExpanded;
  final int totalCount;
  final VoidCallback onToggle;
  final OnAddPhoto onAdd;
  final OnDeleteSavedPhoto onDeleteSaved;
  final OnDeletePendingPhoto onDeletePending;

  static const int maxPhotos = 10;

  const PhotoSection({
    super.key,
    required this.savedPhotos,
    required this.pendingPhotos,
    required this.isExpanded,
    required this.totalCount,
    required this.onToggle,
    required this.onAdd,
    required this.onDeleteSaved,
    required this.onDeletePending,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row with premium ripple feedback
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: t.border, width: AppStroke.hairline),
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.photo,
                    size: AppIconSize.xs, color: t.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  totalCount == 0
                      ? 'Photos'
                      : 'Photos ($totalCount/$maxPhotos)',
                  style: AppTextStyles.labelLargeSerif(t.textTertiary, fp),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: AppDuration.normal,
                  curve: AppCurve.enter,
                  child: Icon(
                    AppIcons.chevronRight,
                    size: AppIconSize.xs,
                    color: t.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expandable photo strip with smooth size animation
        ClipRect(
          child: AnimatedSize(
            duration: AppDuration.normal,
            curve: AppCurve.enter,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? _buildPhotoStrip(context)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoStrip(BuildContext context) {
    return SizedBox(
      height: AppComponentSize.photoStripHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          for (int i = 0; i < pendingPhotos.length; i++)
            _PhotoPendingThumb(
              photo: pendingPhotos[i],
              onDelete: () => onDeletePending(pendingPhotos[i]),
              onTap: () => _openViewer(context, i),
            ),
          for (int i = 0; i < savedPhotos.length; i++)
            _PhotoSavedThumb(
              photo: savedPhotos[i],
              onDelete: () => onDeleteSaved(savedPhotos[i]),
              onTap: () => _openViewer(context, pendingPhotos.length + i),
            ),
          if (totalCount < maxPhotos) _AddPhotoButton(onTap: onAdd),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    FocusManager.instance.primaryFocus?.unfocus();

    final viewerItems = <PhotoViewerItem>[
      for (final p in pendingPhotos)
        PhotoViewerItem.fromXFile(p.xFile, bytes: p.bytes),
      for (final p in savedPhotos) PhotoViewerItem.fromPhoto(p),
    ];

    PhotoFullViewer.open(
      context,
      photos: viewerItems,
      initialIndex: index,
      onDelete: (idx) {
        if (idx < pendingPhotos.length) {
          onDeletePending(pendingPhotos[idx]);
        } else {
          onDeleteSaved(savedPhotos[idx - pendingPhotos.length]);
        }
      },
    );
  }
}

class _PhotoPendingThumb extends StatelessWidget {
  final PendingPhoto photo;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PhotoPendingThumb({
    required this.photo,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Container(
      width: AppComponentSize.photoThumbSize,
      height: AppComponentSize.photoThumbSize,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: t.accentLight,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
                side: BorderSide(color: AppColors.warning, width: AppStroke.thin),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Image.file(
                  File(photo.xFile.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(AppIcons.imageBroken, color: t.textTertiary),
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _DeletePhotoButton(onTap: onDelete),
          ),
        ],
      ),
    );
  }
}

class _PhotoSavedThumb extends StatelessWidget {
  final dynamic photo;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PhotoSavedThumb({
    required this.photo,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final signedUrl = photo?.signedUrl as String?;
    final localPath = photo?.localPath as String?;
    final photoPath = signedUrl ?? localPath ?? '';

    return Container(
      width: AppComponentSize.photoThumbSize,
      height: AppComponentSize.photoThumbSize,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: t.accentLight,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
                side: BorderSide(color: t.accentMuted.withValues(alpha: 0.9), width: AppStroke.thin),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: _buildImage(context, photoPath),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _DeletePhotoButton(onTap: onDelete),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, String path) {
    final t = context.poppyTheme;
    final signedUrl = photo?.signedUrl as String?;

    if (signedUrl != null && signedUrl.isNotEmpty) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(AppIcons.imageBroken, color: t.textTertiary),
      );
    }

    if (path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(AppIcons.imageBroken, color: t.textTertiary),
      );
    }

    return Icon(AppIcons.imageBroken, color: t.textTertiary);
  }
}

class _DeletePhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeletePhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Material(
      color: t.accentMuted.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            AppIcons.close,
            size: AppIconSize.xs * 0.8,
            color: t.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Container(
      width: AppComponentSize.photoThumbSize,
      height: AppComponentSize.photoThumbSize,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: t.border, width: AppStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            AppIcons.add,
            color: t.textTertiary,
            size: AppIconSize.md,
          ),
        ),
      ),
    );
  }
}
