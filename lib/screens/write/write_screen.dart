import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
import 'dart:ui' as ui;

// ─────────────────────────────────────────────────────────────
// POPPY — Write Screen
// Location: lib/screens/write/write_screen.dart
// ─────────────────────────────────────────────────────────────

const int kWordLimit = 10000;

class _PendingPhoto {
  final XFile xFile;
  final Uint8List? bytes;

  const _PendingPhoto({required this.xFile, this.bytes});
}

class WriteScreen extends StatefulWidget {
  final String? entryId;
  final bool saveOnPop; // true = save only when popping, false = auto-save

  const WriteScreen({super.key, this.entryId, this.saveOnPop = false});

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
  bool _hasUnsavedChanges = false;

  String _lastSavedTitle = '';
  String _lastSavedContent = '';
  DateTime? _lastSavedDate;
  EntryColorData? _lastSavedColor;
  int _lastSavedPhotoCount = 0;

  bool get _isEditing => _existingEntry != null;
  int get _totalPhotos => _savedPhotos.length + _pendingPhotos.length;
  int get _liveWordCount => Entry.countWords(_contentController.text);
  bool get _isOverLimit => _liveWordCount > kWordLimit;

  bool get _hasChanges {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    return title != _lastSavedTitle ||
        content != _lastSavedContent ||
        _entryDate != _lastSavedDate ||
        _selectedColor != _lastSavedColor ||
        _pendingPhotos.isNotEmpty ||
        _savedPhotos.length != _lastSavedPhotoCount;
  }

  @override
  void initState() {
    super.initState();

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);

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

      _lastSavedTitle = entry.title;
      _lastSavedContent = entry.content;
      _lastSavedDate = entry.entryDate;
      _lastSavedColor = entry.colorTag;
      _lastSavedPhotoCount = 0;
    });

    try {
      final photos = await _photosService.fetchForEntry(entry.id);
      if (mounted) {
        setState(() {
          _savedPhotos = photos;
          _lastSavedPhotoCount = photos.length;
          _photosExpanded = photos.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  void _onChanged() {
    if (widget.saveOnPop) return; // Skip auto-save if saveOnPop is true

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_isSaving || !_hasChanges) return;

    await _saveSilently();
  }

  Future<void> _saveSilently() async {
    if (_isSaving) return;
    _isSaving = true;

    final provider = context.read<EntriesProvider>();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final wordCount = Entry.countWords(content);

    try {
      Entry? updatedEntry;

      // 1. CREATE or UPDATE ENTRY
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

      if (updatedEntry == null) return;

      setState(() {
        _existingEntry = updatedEntry;
        _lastSavedTitle = title;
        _lastSavedContent = content;
        _lastSavedDate = _entryDate;
        _lastSavedColor = _selectedColor;
      });

      // 2. UPLOAD PENDING PHOTOS
      if (_pendingPhotos.isNotEmpty && _existingEntry != null) {
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

        // 3. REFRESH SAVED PHOTOS
        final photos = await _photosService.fetchForEntry(_existingEntry!.id);

        if (mounted) {
          setState(() {
            _savedPhotos = photos;
            _lastSavedPhotoCount = photos.length;
          });
        }
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      // Silent fail - you could add error handling toast here
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _saveBeforePop() async {
    if (!_hasChanges || _isSaving) return;
    await _saveSilently();
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
      if (!widget.saveOnPop) _onChanged();
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
      _hasUnsavedChanges = true;
    });

    if (!widget.saveOnPop) _onChanged();
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
                borderRadius: BorderRadius.circular(2),
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
    if (!widget.saveOnPop) _onChanged();
  }

  void _onDeletePendingPhoto(_PendingPhoto p) {
    setState(() {
      _pendingPhotos.remove(p);
      _hasUnsavedChanges = true;
    });
    if (!widget.saveOnPop) _onChanged();
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

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return WillPopScope(
      onWillPop: () async {
        if (widget.saveOnPop && _hasChanges) {
          await _saveBeforePop();
        }
        return true;
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
              if (widget.saveOnPop && _hasChanges) {
                await _saveBeforePop();
              }
              Navigator.of(context).pop();
            },
            icon: Icon(AppIcons.back, color: t.background, size: AppIconSize.sm),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  height: 44,
                  width: 44,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: t.accentMuted, width: 2),
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
                        style: TextStyle(
                          color: t.textTertiary,
                          fontSize: 10,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _titleController,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    textCapitalization: TextCapitalization.words,
                    style: AppTextStyles.writeTitle(t.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: t.surface,
                      hintText: 'Title',
                      hintStyle: AppTextStyles.writeTitle(t.textTertiary)
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            AnimatedBuilder(
              animation: Listenable.merge([_titleController, _contentController]),
              builder: (context, _) {
                return _hasUnsavedChanges && widget.saveOnPop
                    ? Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                  ),
                )
                    : const SizedBox.shrink();
              },
            ),
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
                side: BorderSide(color: t.border, width: 0.5),
              ),
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'delete') _onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  height: 44,
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
                        style: AppTextStyles.writeBody(
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
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
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.wordCount,
                                size: AppIconSize.xs,
                                color: t.textTertiary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AnimatedBuilder(
                                animation: _contentController,
                                builder: (_, __) {
                                  final count = _liveWordCount;
                                  final over = count > kWordLimit;
                                  final near = count > kWordLimit * 0.9;
                                  final color = over
                                      ? AppColors.error
                                      : near
                                      ? AppColors.warning
                                      : t.textTertiary;
                                  return Text(
                                    '$count / $kWordLimit words',
                                    style: AppTextStyles.meta(color),
                                  );
                                },
                              ),
                              const Spacer(),
                              ColorTagPicker(
                                selected: _selectedColor,
                                onSelected: (c) {
                                  setState(() => _selectedColor = c);
                                  if (!widget.saveOnPop) _onChanged();
                                },
                              ),
                            ],
                          ),
                        ),

                        // Writing area
                        Expanded(
                          child: TextField(
                            controller: _contentController,
                            style: AppTextStyles.writeBody(t.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Write anything…',
                              hintStyle: AppTextStyles.writeBody(t.textTertiary),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
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

// ─────────────────────────────────────────────────────────────
// Photo Section
// ─────────────────────────────────────────────────────────────

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
                Icon(AppIcons.photo, size: AppIconSize.xs, color: t.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  totalCount == 0
                      ? 'Photos'
                      : 'Photos ($totalCount/$maxPhotos)',
                  style: AppTextStyles.meta(t.textTertiary),
                ),
                const Spacer(),
                Icon(
                  isExpanded
                      ? AppIcons.chevronDown
                      : AppIcons.chevronRight,
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
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 0),
          secondChild: SizedBox(
            height: 88,
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
                if (totalCount < maxPhotos)
                  _AddPhotoButton(onTap: onAdd),
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
        : Image.network(pending.xFile.path, fit: BoxFit.cover);

    return Stack(
      children: [
        Container(
          width: 74,
          height: 80,
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
          top: 4,
          left: 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: t.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),

        /// Delete button
        Positioned(
          top: 3,
          right:13,
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
          builder: (_) =>
              _FullscreenViewer(url: photo.signedUrl ?? ''),
        ),
      ),
      child: Stack(
        children: [
          Container(
            width: 74,
            height: 80,
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
            top: 3,
            right:13,
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
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: t.accentMuted.withOpacity(0.9),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(AppIcons.close, size: AppIconSize.xs, color: t.textPrimary,
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
        width: 74,
        height: 80,
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
