import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/color_tag_picker.dart';
import 'package:poppy/core/widgets/photo_strip.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/models/photo.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/services/photos_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Write Screen
//  Location: lib/screens/write/write_screen.dart
//
//  Used for both creating a new entry and editing an existing
//  one. Pass entryId to edit, leave null to create.
//
//  Layout (top to bottom):
//    AppBar  — date on left, save button on right
//    Title field
//    Content field (expands to fill space)
//    Photo strip  — completely separate from text
//    Color tag picker
// ─────────────────────────────────────────────────────────────

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
  List<Photo> _savedPhotos = [];
  List<File> _pendingFiles = [];
  bool _isSaving = false;
  bool _isLoadingPhotos = false;
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

  // ── Load existing entry for editing ───────────────────────

  Future<void> _loadExistingEntry() async {
    final provider = context.read<EntriesProvider>();
    final entry = provider.getById(widget.entryId!);
    if (entry == null) return;

    _existingEntry = entry;
    _titleController.text = entry.title;
    _contentController.text = entry.content;
    setState(() => _selectedColor = entry.colorTag);

    // Load photos separately
    setState(() => _isLoadingPhotos = true);
    try {
      final photos = await _photosService.fetchForEntry(entry.id);
      setState(() => _savedPhotos = photos);
    } finally {
      setState(() => _isLoadingPhotos = false);
    }
  }

  // ── Photo actions ─────────────────────────────────────────

  Future<void> _onAddPhoto() async {
    final total = _savedPhotos.length + _pendingFiles.length;
    if (total >= PhotoStrip.maxPhotos) return;

    // Let user pick source
    final source = await _showPhotoSourceSheet();
    if (source == null) return;

    final file = await _photosService.pickPhoto(fromCamera: source == 'camera');
    if (file == null) return;

    setState(() => _pendingFiles.add(file));
  }

  Future<String?> _showPhotoSourceSheet() async {
    final t = context.poppyTheme;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusLG)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: kSpaceSM),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: kSpaceLG),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: t.accent),
              title: Text('Choose from gallery',
                  style: TextStyle(color: t.textPrimary)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: t.accent),
              title:
              Text('Take a photo', style: TextStyle(color: t.textPrimary)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: kSpaceMD),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeleteSavedPhoto(Photo photo) async {
    await _photosService.delete(photo);
    setState(() => _savedPhotos.remove(photo));
  }

  void _onDeletePendingFile(File file) {
    setState(() => _pendingFiles.remove(file));
  }

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
        // ── Update existing entry ──────────────────────────
        final updated = _existingEntry!.copyWith(
          title: title,
          content: content,
          colorTag: _selectedColor,
          wordCount: wordCount,
        );
        await provider.updateEntry(updated);
        entryId = updated.id;
      } else {
        // ── Create new entry ───────────────────────────────
        final newEntry = Entry(
          id: '',
          userId: '',
          title: title,
          content: content,
          colorTag: _selectedColor,
          wordCount: wordCount,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await provider.createEntry(newEntry);
        if (created == null) throw Exception('Failed to create entry.');
        entryId = created.id;
      }

      // ── Upload pending photos ──────────────────────────
      for (int i = 0; i < _pendingFiles.length; i++) {
        await _photosService.upload(
          file: _pendingFiles[i],
          entryId: entryId,
          orderIndex: _savedPhotos.length + i,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
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
            child:
            Text('Cancel', style: TextStyle(color: t.textSecondary)),
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
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing
              ? DateFormat('MMM d, yyyy')
              .format(_existingEntry?.createdAt ?? DateTime.now())
              : DateFormat('MMM d, yyyy').format(DateTime.now()),
          style: TextStyle(
            fontSize: 14,
            color: t.textTertiary,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          // Delete — only shown when editing
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: t.textTertiary),
              onPressed: _onDelete,
              tooltip: 'Delete entry',
            ),

          // Save button
          Padding(
            padding: const EdgeInsets.only(right: kSpaceSM),
            child: TextButton(
              onPressed: _isSaving ? null : _onSave,
              child: _isSaving
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.accent,
                ),
              )
                  : Text(
                'Save',
                style: TextStyle(
                  color: t.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Title field ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpaceLG, kSpaceSM, kSpaceLG, 0,
            ),
            child: TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: t.textPrimary,
                letterSpacing: -0.3,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: t.textTertiary,
                  letterSpacing: -0.3,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 1,
            ),
          ),

          // Hairline under title
          Divider(height: kSpaceMD, thickness: 0.5, color: t.border,
              indent: kSpaceLG, endIndent: kSpaceLG),

          // ── Content field (expands) ──────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
              child: TextField(
                controller: _contentController,
                style: TextStyle(
                  fontSize: 15,
                  color: t.textPrimary,
                  height: 1.7,
                ),
                decoration: InputDecoration(
                  hintText: 'Write anything…',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: t.textTertiary,
                    height: 1.7,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: kSpaceSM),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),

          // ── Photo strip ───────────────────────────────────
          PhotoStrip(
            savedPhotos: _savedPhotos,
            pendingFiles: _pendingFiles,
            onAddPhoto: _onAddPhoto,
            onDeleteSavedPhoto: _onDeleteSavedPhoto,
            onDeletePendingFile: _onDeletePendingFile,
          ),

          // ── Color tag picker ──────────────────────────────
          ColorTagPicker(
            selected: _selectedColor,
            onSelected: (color) => setState(() => _selectedColor = color),
          ),
        ],
      ),
    );
  }
}