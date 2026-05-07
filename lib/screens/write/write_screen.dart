import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/color_tag_picker.dart';
import 'package:poppy/core/widgets/photo_strip.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/models/photo.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/services/photos_service.dart';
import 'package:provider/provider.dart';

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

  EntryColorData _selectedColor = EntryColors.defaultColor;
  DateTime _entryDate = DateTime.now();
  List<Photo> _savedPhotos = [];
  List<File> _pendingFiles = [];
  bool _isSaving = false;
  Entry? _existingEntry;

  bool get _isEditing => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExistingEntry();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEntry() async {
    final entry = context.read<EntriesProvider>().getById(widget.entryId!);
    if (entry == null) return;
    _existingEntry = entry;
    _titleController.text = entry.title;
    _contentController.text = entry.content;
    setState(() {
      _selectedColor = entry.colorTag;
      _entryDate = entry.entryDate;
    });
    try {
      final photos = await _photosService.fetchForEntry(entry.id);
      if (mounted) setState(() => _savedPhotos = photos);
    } catch (_) {}
  }

  // ── Date picker ───────────────────────────────────────────

  Future<void> _pickDate() async {
    final t = context.poppyTheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: t.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  // ── Photo actions ─────────────────────────────────────────

  Future<void> _onAddPhoto() async {
    if (_savedPhotos.length + _pendingFiles.length >= PhotoStrip.maxPhotos) {
      return;
    }
    final source = await _showSourceSheet();
    if (source == null) return;
    final file = await _photosService.pickPhoto(fromCamera: source == 'camera');
    if (file == null) return;
    setState(() => _pendingFiles.add(file));
  }

  Future<String?> _showSourceSheet() {
    final t = context.poppyTheme;
    return showModalBottomSheet<String>(
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
  }

  void _onDeletePendingFile(File file) =>
      setState(() => _pendingFiles.remove(file));

  // ── Save ──────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final wordCount = Entry.countWords(content);
    final provider = context.read<EntriesProvider>();

    try {
      String entryId;
      if (_isEditing && _existingEntry != null) {
        final updated = _existingEntry!.copyWith(
          title: title,
          content: content,
          colorTag: _selectedColor,
          wordCount: wordCount,
          entryDate: _entryDate,
        );
        await provider.updateEntry(updated);
        entryId = updated.id;
      } else {
        final newEntry = Entry(
          id: '',
          userId: '',
          title: title,
          content: content,
          colorTag: _selectedColor,
          wordCount: wordCount,
          entryDate: _entryDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await provider.createEntry(newEntry);
        if (created == null) throw Exception('Failed to create entry.');
        entryId = created.id;
      }
      for (int i = 0; i < _pendingFiles.length; i++) {
        await _photosService.upload(
          file: _pendingFiles[i],
          entryId: entryId,
          orderIndex: _savedPhotos.length + i,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────

  Future<void> _onDelete() async {
    if (_existingEntry == null) return;
    final t = context.poppyTheme;
    final confirmed = await showDialog<bool>(
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
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    }
  }

  // ── Uniform Header Pill Helper ────────────────────────────
  // Creates a consistently sized and styled container for header items
  Widget _headerPill({required Widget child}) {
    final t = context.poppyTheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Scaffold(
      backgroundColor: t.accent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              // ───────────────── HEADER ─────────────────

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button Pill
                  GestureDetector(
                    child: Icon(
                      AppIcons.back,
                      color: t.background,
                      size: AppIconSize.sm,
                    ),
                    onTap: () => Navigator.pop(context),
                  ),

                  const SizedBox(
                    width: AppSpacing.sm,
                  ),

                  // Date Pill
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: t.accentMuted,
                        width: 3,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: _pickDate,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(_entryDate),
                              style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM')
                                  .format(_entryDate)
                                  .toUpperCase(),
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
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Title Pill
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _titleController,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppTextStyles.writeTitle(t.textPrimary),
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: t.surface,
                          hintText: 'Title',
                          hintStyle: AppTextStyles.writeTitle(t.textTertiary),
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Delete Pill
                  if (_isEditing) ...[
                    const SizedBox(
                      width: AppSpacing.sm,
                    ),
                    GestureDetector(
                      child: Icon(
                        AppIcons.delete,
                        color: t.background,
                        size: AppIconSize.md,
                      ),
                      onTap: () => _onDelete(),
                    ),
                    const SizedBox(
                      width: AppSpacing.sm,
                    ),
                    GestureDetector(
                      child: _isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.surface,
                              ),
                            )
                          : Icon(
                              AppIcons.save,
                              color: t.textPrimary,
                              size: AppIconSize.md,
                            ),
                      onTap: () => _isSaving ? null : _onSave(),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // ───────────────── PAGE ─────────────────
              Expanded(
                child: Container(
                  height: double.minPositive,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      // Meta row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(AppIcons.time,
                                    size: AppIconSize.xs,
                                    color: t.textTertiary),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  _existingEntry != null
                                      ? DateFormat('h:mm a')
                                          .format(_existingEntry!.updatedAt)
                                      : DateFormat('h:mm a')
                                          .format(DateTime.now()),
                                  style: AppTextStyles.meta(t.textTertiary),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Icon(AppIcons.wordCount,
                                    size: AppIconSize.xs,
                                    color: t.textTertiary),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${_existingEntry?.wordCount ?? 0} words',
                                  style: AppTextStyles.meta(t.textTertiary),
                                ),
                                const SizedBox(width: AppSpacing.md),
                              ],
                            ),
                            // Colors
                            ColorTagPicker(
                              selected: _selectedColor,
                              onSelected: (c) => setState(
                                () => _selectedColor = c,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Writing area
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          style: AppTextStyles.writeBody(
                            t.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            hintText: 'Write anything…',
                            hintStyle: AppTextStyles.writeBody(
                              t.textTertiary,
                            ),
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                          textAlign: TextAlign.start,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),

                      // Photos
                      if (_savedPhotos.isNotEmpty) ...[
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            itemCount: _savedPhotos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final photo = _savedPhotos[i];
                              return GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    fullscreenDialog: true,
                                    builder: (_) => _FullscreenViewer(
                                      photos: _savedPhotos,
                                      initialIndex: i,
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: photo.signedUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: photo.signedUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                Container(color: t.surface),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              color: t.surface,
                                              child: Icon(AppIcons.imageBroken,
                                                  color: t.textTertiary),
                                            ),
                                          )
                                        : Container(color: t.surface),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: AppComponentSize.photoStripHeight +
                              AppSpacing.xxl,
                          child: PhotoStrip(
                            savedPhotos: _savedPhotos,
                            pendingFiles: _pendingFiles,
                            onAddPhoto: _onAddPhoto,
                            onDeleteSavedPhoto: _onDeleteSavedPhoto,
                            onDeletePendingFile: _onDeletePendingFile,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenViewer extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const _FullscreenViewer({required this.photos, required this.initialIndex});

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.photoViewerBg,
      appBar: AppBar(
        backgroundColor: AppColors.photoViewerBg,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: AppColors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) {
          final photo = widget.photos[i];
          return InteractiveViewer(
            child: Center(
              child: photo.signedUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photo.signedUrl!,
                      fit: BoxFit.contain,
                    )
                  : Icon(AppIcons.imageBroken,
                      color: Colors.white54, size: AppIconSize.xl),
            ),
          );
        },
      ),
    );
  }
}
