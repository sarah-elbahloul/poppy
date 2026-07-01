import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bidi_text/bidi_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';
import 'package:poppy/features/journal/data/models/photo.dart';
import 'package:poppy/features/journal/presentation/providers/entries_provider.dart';
import 'package:poppy/features/journal/data/services/photos_service.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:poppy/features/journal/presentation/widgets/color_tag_selector.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Write Screen
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

  TagColorData _selectedColor = EntryTags.defaultColor;
  DateTime _entryDate = DateTime.now();
  List<Photo> _savedPhotos = [];
  List<Photo> _initialPhotos = [];
  List<_PendingPhoto> _pendingPhotos = [];

  bool _photosExpanded = false;
  Entry? _existingEntry;

  Timer? _debounce;
  bool _isSaving = false;

  DateTime? _lastLimitSnackbarTime;

  bool get _isEditing => _existingEntry != null;
  int get _totalPhotos => _savedPhotos.length + _pendingPhotos.length;
  int get _liveWordCount => Entry.countWords(_contentController.text);

  bool get _photosChanged {
    if (_savedPhotos.length != _initialPhotos.length) {
      return true;
    }
    final currentIds = _savedPhotos.map((p) => p.id).toSet();
    final initialIds = _initialPhotos.map((p) => p.id).toSet();
    return !setEquals(currentIds, initialIds);
  }

  bool get _hasChanges {
    if (_existingEntry == null) {
      return _titleController.text.trim().isNotEmpty ||
          _contentController.text.trim().isNotEmpty ||
          _pendingPhotos.isNotEmpty;
    }

    return _titleController.text.trim() != _existingEntry!.title ||
        _contentController.text.trim() != _existingEntry!.content ||
        _entryDate != _existingEntry!.entryDate ||
        _selectedColor != _existingEntry!.colorTag ||
        _pendingPhotos.isNotEmpty ||
        _photosChanged;
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
          _initialPhotos = List.of(photos);
          _photosExpanded = photos.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<bool> _save() async {
    if (!_hasChanges || _isSaving) return true;

    final content = _contentController.text.trim();
    final title = _titleController.text.trim();
    final wordCount = Entry.countWords(content);

    if (wordCount > kWordLimit) {
      _maybeShowLimitSnackBar();
      return false;
    }

    _isSaving = true;

    try {
      final provider = context.read<EntriesProvider>();
      Entry? updatedEntry;

      if (_isEditing && _existingEntry != null) {
        final draft = _existingEntry!.copyWith(
          title: title,
          content: content,
          colorTag: _selectedColor,
          entryDate: _entryDate,
          wordCount: wordCount,
          updatedAt: DateTime.now(),
        );
        updatedEntry = await provider.updateEntry(draft);
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
        final photos = await _photosService.fetchForEntry(_existingEntry!.id);

        if (mounted) {
          setState(() {
            _savedPhotos = photos;
          });
        }
      }

      return true;
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

    bool useCamera = false;
    if (!kIsWeb) {
      final source = await _showSourceSheet();
      if (source == null) return;
      useCamera = (source == 'camera');
    }

    if (useCamera) {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xFile == null) return;

      Uint8List? bytes;
      if (kIsWeb) bytes = await xFile.readAsBytes();

      setState(() {
        _pendingPhotos.add(_PendingPhoto(xFile: xFile, bytes: bytes));
        _photosExpanded = true;
      });
    } else {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty) return;

      final int remaining = 10 - _totalPhotos;
      final int countToTake =
      pickedFiles.length > remaining ? remaining : pickedFiles.length;
      final List<XFile> toProcess = pickedFiles.take(countToTake).toList();

      final List<_PendingPhoto> newPhotos = [];
      for (final xFile in toProcess) {
        Uint8List? bytes;
        if (kIsWeb) bytes = await xFile.readAsBytes();
        newPhotos.add(_PendingPhoto(xFile: xFile, bytes: bytes));
      }

      if (mounted) {
        setState(() {
          _pendingPhotos.addAll(newPhotos);
          if (newPhotos.isNotEmpty) _photosExpanded = true;
        });

        if (pickedFiles.length > remaining) {
          PoppySnackbar.warning(
            context,
            'Only 10 photos allowed. ${pickedFiles.length - remaining} photos were skipped.',
          );
        }
      }
    }
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
    final confirmed = await PoppyDialog.showDestructive(
      context,
      title: 'Delete entry?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
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
    if (_lastLimitSnackbarTime != null &&
        now.difference(_lastLimitSnackbarTime!).inSeconds < 3) {
      return;
    }
    _lastLimitSnackbarTime = now;

    if (!mounted) return;
    PoppySnackbar.warning(
      context,
      'You’ve hit the word limit. Try shortening your entry to save.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!_hasChanges) {
          Navigator.of(context).pop();
          return;
        }

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
                    border: Border.all(
                        color: t.accentMuted, width: AppStroke.thick),
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
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        DateFormat('MMM').format(_entryDate).toUpperCase(),
                        style: AppTextStyles.labelSmall(t.textTertiary, fp),
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
                    style: AppTextStyles.headlineSmall(t.textPrimary, fp),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: t.surface,
                      hintText: 'Title',
                      hintStyle: AppTextStyles.headlineSmall(t.textTertiary, fp)
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
                          fp,
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, 0, AppSpacing.sm),
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
                                        Flexible(
                                          child: Text(
                                            '$count / $kWordLimit words',
                                            style:
                                            AppTextStyles.labelLargeSerif(
                                                color, fp),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (over) ...[
                                          const SizedBox(
                                            width: AppSpacing.sm,
                                          ),
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
                              Flexible(
                                child: ColorTagSelector(
                                  selected: _selectedColor,
                                  onSelected: (c) {
                                    if (c != null) {
                                      setState(() => _selectedColor = c);
                                    }
                                  },
                                  leading: Icon(
                                    AppIcons.tag,
                                    size: AppIconSize.xs,
                                    color: t.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,

                            ),
                            child: BidiTextField(
                              controller: _contentController,
                              autofocus: true,
                              style: AppTextStyles.bodyLarge(t.textPrimary, fp),
                              decoration: InputDecoration(
                                hintText: 'Write anything…',
                                hintStyle:
                                AppTextStyles.bodyLarge(t.textTertiary, fp),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,

                              ),
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              textAlign: TextAlign.start,
                              inputFormatters: [
                                WordLimitFormatter(
                                  kWordLimit,
                                  onBlocked: _maybeShowLimitSnackBar,
                                ),
                              ],
                            ),
                          ),
                        ),

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

    if (newCount <= maxWords) return newValue;
    if (newCount <= oldCount) return newValue;

    onBlocked?.call();
    return oldValue;
  }
}

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
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    final allPhotos = [...pendingPhotos, ...savedPhotos];

    void openViewer(int index) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullscreenViewer(
            photos: allPhotos,
            initialIndex: index,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                  style: AppTextStyles.labelLargeSerif(t.textTertiary, fp),
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
                for (int i = 0; i < pendingPhotos.length; i++)
                  _PhotoPendingThumb(
                    pending: pendingPhotos[i],
                    onDelete: () => onDeletePending(pendingPhotos[i]),
                    onTap: () => openViewer(i),
                  ),
                for (int i = 0; i < savedPhotos.length; i++)
                  _PhotoSavedThumb(
                    photo: savedPhotos[i],
                    onDelete: () => onDeleteSaved(savedPhotos[i]),
                    onTap: () => openViewer(pendingPhotos.length + i),
                  ),
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
  final VoidCallback onTap;

  const _PhotoPendingThumb({
    required this.pending,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    final image = kIsWeb && pending.bytes != null
        ? Image.memory(pending.bytes!, fit: BoxFit.cover)
        : Image.file(File(pending.xFile.path), fit: BoxFit.cover);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: AppComponentSize.photoThumbSize,
            height: AppComponentSize.photoThumbSize,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: t.accent.withValues(alpha: 0.5),
                width: AppStroke.thin,
              ),
              color: t.accentLight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppRadius.sm - AppStroke.hairline,
              ),
              child: image,
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
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

class _PhotoSavedThumb extends StatelessWidget {
  final Photo photo;
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
    final photoPath = photo.signedUrl ?? photo.localPath ?? '';

    return GestureDetector(
      onTap: onTap,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppRadius.sm - AppStroke.hairline,
              ),
              child: photo.signedUrl != null
                  ? Image.network(
                photoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(AppIcons.imageBroken, color: t.textTertiary),
              )
                  : Image.file(File(photoPath), fit: BoxFit.cover),
            ),
          ),
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
            color: t.accentMuted.withValues(alpha: 0.9),
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

class _FullscreenViewer extends StatefulWidget {
  final List<dynamic> photos;
  final int initialIndex;

  const _FullscreenViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.photoViewerBg,
      appBar: AppBar(
        backgroundColor: AppColors.photoViewerBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${_currentIndex + 1} of ${widget.photos.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final item = widget.photos[index];

          Widget image = const Icon(
            AppIcons.imageBroken,
            color: Colors.white54,
            size: AppIconSize.xl,
          );

          dynamic url;
          dynamic local;
          if (item is Photo) {
            url = item.signedUrl;
            local = item.localPath;
          } else if (item is _PendingPhoto) {
            local = item.xFile.path;
          }

          if (url != null && url.isNotEmpty) {
            image = Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                if (local != null && local.isNotEmpty) {
                  return Image.file(File(local), fit: BoxFit.contain);
                }
                return const Icon(
                  AppIcons.imageBroken,
                  color: Colors.white54,
                  size: AppIconSize.xl,
                );
              },
            );
          } else if (local != null && local.isNotEmpty) {
            image = Image.file(File(local), fit: BoxFit.contain);
          }

          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(child: image),
          );
        },
      ),
    );
  }
}