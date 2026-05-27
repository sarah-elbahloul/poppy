import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bidi_text/bidi_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/color_tag_picker.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/models/photo.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/services/photos_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
// POPPY — Write Screen
// Location: lib/screens/write/write_screen.dart
// ─────────────────────────────────────────────────────────────

const int kWordLimit = 10000;

class WriteScreen extends StatefulWidget {
  final String? entryId;

  const WriteScreen({super.key, this.entryId});

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _photosService = PhotosService();
  final _picker = ImagePicker();

  EntryColorData _selectedColor = EntryColors.defaultColor;
  DateTime _entryDate = DateTime.now();
  List<Photo> _savedPhotos = [];
  List<_PendingPhoto> _pendingPhotos = [];

  bool _photosExpanded = false;
  Entry? _existingEntry;

  Timer? _debounce;
  bool _isSaving = false;

  DateTime? _lastLimitSnackbarTime;

  bool get _isEditing => _existingEntry != null;

  int get _totalPhotos => _savedPhotos.length + _pendingPhotos.length;

  int get _liveWordCount => Entry.countWords(_contentController.text);

  bool get _hasChanges {
    // Safely handle new entries where _existingEntry is null
    if (_existingEntry == null) {
      return _titleController.text.trim().isNotEmpty ||
          _contentController.text.trim().isNotEmpty ||
          _pendingPhotos.isNotEmpty;
    }

    // Compare against existing entry data
    return _titleController.text.trim() != _existingEntry!.title ||
        _contentController.text.trim() != _existingEntry!.content ||
        _entryDate != _existingEntry!.entryDate ||
        _selectedColor != _existingEntry!.colorTag ||
        _pendingPhotos.isNotEmpty ||
        _savedPhotos.length != _existingEntry!.photoUrls.length;
  }

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      _loadExistingEntry();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEntry() async {
    final entry = context.read<EntriesProvider>().getById(widget.entryId!);
    if (entry == null) return;

    setState(() {
      _existingEntry = entry;
      _titleController.text = entry.title;
      _contentController.text = entry.content;
      _selectedColor = entry.colorTag;
      _entryDate = entry.entryDate;
    });

    try {
      final photos = await _photosService.fetchForEntry(entry.id);
      if (mounted) {
        setState(() {
          _savedPhotos = photos;
          _photosExpanded = photos.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<bool> _save() async {
    if (!_hasChanges || _isSaving) return true; // allow pop if nothing changed

    final content = _contentController.text.trim();
    final wordCount = Entry.countWords(content);

    // 🚫 BLOCK: over limit
    if (wordCount > kWordLimit) {
      _maybeShowLimitSnackBar();
      return false; // do NOT save, do NOT allow pop
    }

    _isSaving = true;

    try {
      final provider = context.read<EntriesProvider>();
      final title = _titleController.text.trim();

      Entry? updatedEntry;

      if (_isEditing && _existingEntry != null) {
        updatedEntry = _existingEntry!.copyWith(
          title: title,
          content: content,
          colorTag: _selectedColor,
          entryDate: _entryDate,
          wordCount: wordCount,
          updatedAt: DateTime.now(),
        );

        await provider.updateEntry(updatedEntry);
      } else {
        updatedEntry = await provider.createEntry(
          Entry(
            id: '',
            userId: '',
            title: title,
            content: content,
            colorTag: _selectedColor,
            entryDate: _entryDate,
            wordCount: wordCount,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (updatedEntry == null) return false;

      setState(() {
        _existingEntry = updatedEntry;
      });

      // Upload photos...
      if (_pendingPhotos.isNotEmpty) {
        for (int i = 0; i < _pendingPhotos.length; i++) {
          final p = _pendingPhotos[i];

          await _photosService.uploadXFile(
            entryId: _existingEntry!.id,
            xFile: p.xFile,
            bytes: p.bytes,
            orderIndex: _savedPhotos.length + i,
          );
        }

        _pendingPhotos.clear();

        final photos =
        await _photosService.fetchForEntry(_existingEntry!.id);

        if (mounted) {
          setState(() {
            _savedPhotos = photos;
          });
        }
      }

      return true; // ✅ success → allow pop
    } catch (e) {
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final t = context.poppyTheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: t.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _entryDate = picked);
    }
  }

  Future<void> _onAddPhoto() async {
    if (_totalPhotos >= 10) return;
    String? source;
    if (!kIsWeb) {
      source = await _showSourceSheet();
      if (source == null) return;
    }
    final xFile = await _picker.pickImage(
      source: (!kIsWeb && source == 'camera')
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
    );
    if (xFile == null) return;
    Uint8List? bytes;
    if (kIsWeb) bytes = await xFile.readAsBytes();

    setState(() {
      _pendingPhotos.add(_PendingPhoto(xFile: xFile, bytes: bytes));
      _photosExpanded = true;
    });
  }

  Future _showSourceSheet() {
    final t = context.poppyTheme;
    return showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: AppComponentSize.sheetHandle,
              height: AppComponentSize.sheetHandleHeight,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: Icon(AppIcons.gallery, color: t.accent),
              title: Text('Choose from gallery',
                  style: TextStyle(color: t.textPrimary)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(AppIcons.camera, color: t.accent),
              title:
              Text('Take a photo', style: TextStyle(color: t.textPrimary)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeleteSavedPhoto(Photo photo) async {
    await _photosService.delete(photo);
    setState(() => _savedPhotos.remove(photo));
  }

  void _onDeletePendingPhoto(_PendingPhoto p) {
    setState(() {
      _pendingPhotos.remove(p);
    });
  }

  Future<void> _onDelete() async {
    if (_existingEntry == null) return;
    final t = context.poppyTheme;
    final confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<EntriesProvider>().deleteEntry(_existingEntry!.id);
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
            (route) => false,
      );
    }
  }

  void _maybeShowLimitSnackBar() {
    final now = DateTime.now();
    // Throttle to prevent spamming the UI when holding down a key
    if (_lastLimitSnackbarTime != null &&
        now.difference(_lastLimitSnackbarTime!).inSeconds < 3) {
      return;
    }
    _lastLimitSnackbarTime = now;

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
        Text('You’ve hit the word limit. Try shortening your entry to save.'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // nothing changed → allow leaving
        if (!_hasChanges) {
          Navigator.of(context).pop();
          return;
        }

        // save first
        final success = await _save();

        if (success && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: t.accent,
        appBar: AppBar(
          actionsPadding: const EdgeInsets.all(AppSpacing.sm),
          toolbarHeight: AppComponentSize.appBarHeight,
          elevation: 0,
          titleSpacing: 0,
          backgroundColor: t.accent,
          leading: IconButton(
            onPressed: () async {
              if (!_hasChanges) {
                Navigator.of(context).pop();
                return;
              }

              final success = await _save();

              if (success && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: _isSaving
                ? SizedBox(
                height: AppIconSize.sm,
                width: AppIconSize.sm,
                child: CircularProgressIndicator(
                    color: t.surface, strokeWidth: AppStroke.thin))
                : Icon(AppIcons.back,
                color: t.background, size: AppIconSize.sm),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  height: AppComponentSize.inputHeight,
                  width: AppComponentSize.inputHeight,
                  padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: t.accentMuted, width: AppStroke.thick),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(_entryDate),
                        style: TextStyle(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM').format(_entryDate).toUpperCase(),
                        style: AppTextStyles.labelSmall(t.textTertiary,),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: AppComponentSize.inputHeight,
                  child: TextField(
                    controller: _titleController,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    textCapitalization: TextCapitalization.words,
                    style: AppTextStyles.headlineMedium(t.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: t.surface,
                      hintText: 'Title',
                      hintStyle: AppTextStyles.headlineMedium(t.textTertiary)
                          .copyWith(fontSize: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide.none,
                      ),
                      isDense: false,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton(
              enabled: _isEditing ? true : false,
              menuPadding: const EdgeInsets.all(0),
              icon: Icon(
                AppIcons.more,
                color: _isEditing ? t.surface : t.textTertiary,
                size: AppIconSize.sm,
              ),
              color: t.accentLight,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: t.border, width: AppStroke.hairline),
              ),
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'delete') _onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  height: AppComponentSize.inputHeight,
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.delete,
                        size: AppIconSize.sm,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Delete entry',
                        style: AppTextStyles.bodyLarge(
                          Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
            child: Column(
              children: [
                // Page
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      children: [
                        // Meta row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.wordCount,
                                size: AppIconSize.xs,
                                color: t.textTertiary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AnimatedBuilder(
                                  animation: _contentController,
                                  builder: (_, __) {
                                    final count = _liveWordCount;
                                    final over = count >= kWordLimit;
                                    final near = count > kWordLimit * 0.8;
                                    final color = over
                                        ? AppColors.error
                                        : near
                                        ? AppColors.warning
                                        : t.textTertiary;

                                    return Row(
                                      children: [
                                        Text(
                                          '$count / $kWordLimit words',
                                          style: AppTextStyles.labelLargeSerif(color),
                                        ),
                                        if (over) ...[
                                          SizedBox(width: AppSpacing.sm,),
                                          const Icon(
                                            AppIcons.info,
                                            color: AppColors.error,
                                            size: AppIconSize.xs,
                                          )
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              ColorTagPicker(
                                selected: _selectedColor,
                                onSelected: (c) {
                                  setState(() => _selectedColor = c);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Writing area
                        Expanded(
                          child: BidiTextField(
                            /*
                            inputFormatters: [WordLimitFormatter(kWordLimit,onBlocked: _maybeShowLimitSnackBar,),],
                            */
                            controller: _contentController,
                            autofocus: true,
                            style: AppTextStyles.bodyLarge(t.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Write anything…',
                              hintStyle:
                              AppTextStyles.bodyLarge(t.textTertiary),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            textAlign: TextAlign.start,
                          ),
                        ),

                        // Collapsible photos
                        _PhotoSection(
                          savedPhotos: _savedPhotos,
                          pendingPhotos: _pendingPhotos,
                          isExpanded: _photosExpanded,
                          totalCount: _totalPhotos,
                          onToggle: () => setState(
                                  () => _photosExpanded = !_photosExpanded),
                          onAdd: _onAddPhoto,
                          onDeleteSaved: _onDeleteSavedPhoto,
                          onDeletePending: _onDeletePendingPhoto,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Safely blocks typing AND pasting when the word limit is exceeded.
/// Prevents destructive truncation of pasted text to avoid bad UX.
class WordLimitFormatter extends TextInputFormatter {
  final int maxWords;
  final VoidCallback? onBlocked;

  WordLimitFormatter(
      this.maxWords, {
        this.onBlocked,
      });

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final newCount = Entry.countWords(newValue.text);
    final oldCount = Entry.countWords(oldValue.text);

    // Allow if at or under limit
    if (newCount <= maxWords) return newValue;

    // Allow if word count decreased (deleting/editing down)
    if (newCount <= oldCount) return newValue;

    // Block: adding words beyond limit (handles both typing & pasting safely)
    onBlocked?.call();
    return oldValue;
  }
}

// ─────────────────────────────────────────────────────────────
// Photo Section
// ─────────────────────────────────────────────────────────────

class _PendingPhoto {
  final XFile xFile;
  final Uint8List? bytes;

  const _PendingPhoto({required this.xFile, this.bytes});
}

class _PhotoSection extends StatelessWidget {
  final List<Photo> savedPhotos;
  final List<_PendingPhoto> pendingPhotos;
  final bool isExpanded;
  final int totalCount;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final ValueChanged<Photo> onDeleteSaved;
  final ValueChanged<_PendingPhoto> onDeletePending;

  static const int maxPhotos = 10;

  const _PhotoSection({
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// HEADER (always visible)
        GestureDetector(
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
                  style: AppTextStyles.labelLargeSerif(t.textTertiary),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? AppIcons.chevronDown : AppIcons.chevronRight,
                  size: AppIconSize.xs,
                  color: t.textTertiary,
                ),
              ],
            ),
          ),
        ),

        /// CONTENT
        AnimatedCrossFade(
          duration: AppDuration.normal,
          crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 0),
          secondChild: SizedBox(
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
                /// Pending first (important UX)
                ...pendingPhotos.map(
                      (p) => _PhotoPendingThumb(
                    pending: p,
                    onDelete: () => onDeletePending(p),
                  ),
                ),

                /// Saved photos
                ...savedPhotos.map(
                      (p) => _PhotoSavedThumb(
                    photo: p,
                    onDelete: () => onDeleteSaved(p),
                  ),
                ),

                /// Add button
                if (totalCount < maxPhotos) _AddPhotoButton(onTap: onAdd),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPendingThumb extends StatelessWidget {
  final _PendingPhoto pending;
  final VoidCallback onDelete;

  const _PhotoPendingThumb({
    required this.pending,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    final image = kIsWeb && pending.bytes != null
        ? Image.memory(pending.bytes!, fit: BoxFit.cover)
        : Image.file(File(pending.xFile.path), fit: BoxFit.cover);

    return Stack(
      children: [
        Container(
          width: AppComponentSize.photoThumbSize,
          height: AppComponentSize.photoThumbSize,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: t.accent.withOpacity(0.5),
              width: AppStroke.thin,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: image,
        ),

        /// Upload indicator dot
        Positioned(
          top: AppSpacing.xs,
          left: AppSpacing.xs,
          child: Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(
              color: t.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),

        /// Delete button
        Positioned(
          top: AppSpacing.xs,
          right: AppSpacing.md,
          child: _DeletePhotoButton(onTap: onDelete),
        ),
      ],
    );
  }
}

class _PhotoSavedThumb extends StatelessWidget {
  final Photo photo;
  final VoidCallback onDelete;

  const _PhotoSavedThumb({
    required this.photo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullscreenViewer(url: photo.signedUrl ?? ''),
        ),
      ),
      child: Stack(
        children: [
          Container(
            width: AppComponentSize.photoThumbSize,
            height: AppComponentSize.photoThumbSize,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: t.accentLight,
              border: Border.all(
                color: t.border,
                width: AppStroke.hairline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              photo.signedUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(AppIcons.imageBroken, color: t.textTertiary),
            ),
          ),

          /// Delete button
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.md,
            child: _DeletePhotoButton(onTap: onDelete),
          ),
        ],
      ),
    );
  }
}

class _DeletePhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeletePhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: t.accentMuted.withOpacity(0.9),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Icon(
            AppIcons.close,
            size: AppIconSize.xs,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppComponentSize.photoThumbSize,
        height: AppComponentSize.photoThumbSize,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: t.surface,
          border: Border.all(
            color: t.border,
            width: AppStroke.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Icon(
          AppIcons.add,
          color: t.textTertiary,
          size: AppIconSize.md,
        ),
      ),
    );
  }
}

class _FullscreenViewer extends StatelessWidget {
  final String url;

  const _FullscreenViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.photoViewerBg,
      appBar: AppBar(
        backgroundColor: AppColors.photoViewerBg,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: InteractiveViewer(
        child: Center(
          child: url.isNotEmpty
              ? Image.network(url, fit: BoxFit.contain)
              : const Icon(AppIcons.imageBroken,
              color: Colors.white54, size: AppIconSize.xl),
        ),
      ),
    );
  }
}