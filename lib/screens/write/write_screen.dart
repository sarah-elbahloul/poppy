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
//  POPPY — Write Screen
//  Location: lib/screens/write/write_screen.dart
// ─────────────────────────────────────────────────────────────

const int kWordLimit = 5000;

class _PendingPhoto {
  final XFile xFile;
  final Uint8List? bytes;

  const _PendingPhoto({required this.xFile, this.bytes});
}

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
  bool _isSaving = false;
  bool _photosExpanded = false;
  Entry? _existingEntry;

  String _originalTitle = '';
  String _originalContent = '';
  EntryColorData? _originalColor;
  DateTime? _originalDate;

  bool get _isEditing => widget.entryId != null;

  int get _totalPhotos => _savedPhotos.length + _pendingPhotos.length;

  int get _liveWordCount => Entry.countWords(_contentController.text);

  bool get _isOverLimit => _liveWordCount > kWordLimit;

  bool get _hasUnsavedChanges =>
      _titleController.text.trim() != _originalTitle ||
      _contentController.text.trim() != _originalContent ||
      _selectedColor.id !=
          (_originalColor?.id ?? EntryColors.defaultColor.id) ||
      _entryDate.year != (_originalDate ?? DateTime.now()).year ||
      _entryDate.month != (_originalDate ?? DateTime.now()).month ||
      _entryDate.day != (_originalDate ?? DateTime.now()).day;

  @override
  void initState() {
    super.initState();
    _originalColor = EntryColors.defaultColor;
    _originalDate = DateTime.now();
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
    _originalTitle = entry.title;
    _originalContent = entry.content;
    _originalColor = entry.colorTag;
    _originalDate = entry.entryDate;
    _titleController.text = entry.title;
    _contentController.text = entry.content;
    setState(() {
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
    if (picked != null) setState(() => _entryDate = picked);
  }

  void _handleBack() async {
    if (!_hasUnsavedChanges && _pendingPhotos.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final t = context.poppyTheme;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved changes'),
        content:
            const Text('You have unsaved changes. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text('Discard', style: TextStyle(color: t.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text('Save', style: TextStyle(color: t.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _onSave();
      return;
    }
    if (result == 'discard') {
      if (mounted) Navigator.of(context).pop();
    }
    // cancel — stay
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

  void _onDeletePendingPhoto(_PendingPhoto p) =>
      setState(() => _pendingPhotos.remove(p));

  Future<void> _onSave() async {
    if (_isSaving) return;
    if (_isOverLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Entry exceeds the $kWordLimit-word limit. Please shorten it.')),
      );
      return;
    }
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
      for (int i = 0; i < _pendingPhotos.length; i++) {
        final p = _pendingPhotos[i];
        await _photosService.uploadXFile(
          xFile: p.xFile,
          bytes: p.bytes,
          entryId: entryId,
          orderIndex: _savedPhotos.length + i,
        );
      }
      if (mounted) Navigator.of(context).pop();
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
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: t.accent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _handleBack,
                      child: Icon(AppIcons.back,
                          color: t.background, size: AppIconSize.sm),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
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
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _titleController,
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTextStyles.writeTitle(t.textPrimary)
                              .copyWith(fontSize: 15),
                          expands: true,
                          maxLines: null,
                          minLines: null,
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
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                          ),
                        ),
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: _onDelete,
                        child: Icon(AppIcons.delete,
                            color: t.background.withOpacity(0.7),
                            size: AppIconSize.sm),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: _isSaving ? null : _onSave,
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: t.surface),
                            )
                          : Icon(AppIcons.save,
                              color: t.surface, size: AppIconSize.md),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

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
                              const SizedBox(width: AppSpacing.sm,),
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
                                onSelected: (c) =>
                                    setState(() => _selectedColor = c),
                              ),
                            ],
                          ),
                        ),

                        // Writing area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, 0),
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
//  Photo Section
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
        GestureDetector(
          onTap: onToggle,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: t.border, width: AppStroke.hairline)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(AppIcons.photo, size: AppIconSize.xs, color: t.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  totalCount == 0 ? 'Photos' : 'Photos ($totalCount)',
                  style: AppTextStyles.photoSectionLabel(t.textTertiary),
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
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md,0, AppSpacing.md, AppSpacing.md),
              children: [
                ...savedPhotos.map((p) =>
                    _SavedThumb(photo: p, onDelete: () => onDeleteSaved(p))),
                ...pendingPhotos.map((p) => _PendingThumb(
                    pending: p, onDelete: () => onDeletePending(p))),
                if (totalCount < maxPhotos) _AddButton(onTap: onAdd),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedThumb extends StatelessWidget {
  final Photo photo;
  final VoidCallback onDelete;

  const _SavedThumb({required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenViewer(url: photo.signedUrl ?? ''),
      )),
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove photo?'),
            content: const Text('This will permanently delete the photo.'),
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
      },
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: t.accentLight,
          border: Border.all(color: t.border, width: AppStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo.signedUrl != null
            ? Image.network(photo.signedUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(AppIcons.imageBroken, color: t.textTertiary))
            : Icon(AppIcons.photo, color: t.textTertiary, size: AppIconSize.sm),
      ),
    );
  }
}

class _PendingThumb extends StatelessWidget {
  final _PendingPhoto pending;
  final VoidCallback onDelete;

  const _PendingThumb({required this.pending, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final image = kIsWeb && pending.bytes != null
        ? Image.memory(pending.bytes!, fit: BoxFit.cover)
        : Image.network(pending.xFile.path, fit: BoxFit.cover);
    return GestureDetector(
      onLongPress: onDelete,
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                  color: t.accent.withOpacity(0.5), width: AppStroke.thin),
            ),
            clipBehavior: Clip.antiAlias,
            child: image,
          ),
          Positioned(
            top: 4,
            right: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: t.accent),
            ),
          ),
        ],
      ),
    );
  }
}

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
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.border, width: AppStroke.thin),
        ),
        child: Icon(AppIcons.add, color: t.textTertiary, size: AppIconSize.md),
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
              : Icon(AppIcons.imageBroken,
                  color: Colors.white54, size: AppIconSize.xl),
        ),
      ),
    );
  }
}
