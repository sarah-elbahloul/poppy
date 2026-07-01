import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';
import 'package:poppy/features/auth/presentation/providers/auth_provider.dart';
import 'package:poppy/features/journal/presentation/providers/entries_provider.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:poppy/features/settings/presentation/widgets/color_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Tags Screen
// ─────────────────────────────────────────────────────────────

class EntryTagsScreen extends StatefulWidget {
  const EntryTagsScreen({super.key});

  @override
  State<EntryTagsScreen> createState() => _EntryTagsScreenState();
}

class _EntryTagsScreenState extends State<EntryTagsScreen> {
  final _uuid = const Uuid();

  bool _isBatchMode = false;
  final Set<String> _selectedTagIds = {};

  bool _isModifiedFromDefaults(List<TagColorData> tags) {
    const defaults = EntryTags.defaults;
    if (tags.length != defaults.length) return true;
    for (var i = 0; i < defaults.length; i++) {
      if (tags[i].id != defaults[i].id ||
          tags[i].name != defaults[i].name ||
          tags[i].color.value != defaults[i].color.value) {
        return true;
      }
    }
    return false;
  }

  void _enterBatchMode([String? withTagSelected]) {
    setState(() {
      _isBatchMode = true;
      if (withTagSelected != null) _selectedTagIds.add(withTagSelected);
    });
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedTagIds.clear();
    });
  }

  void _toggleTagSelected(String id) {
    setState(() {
      if (_selectedTagIds.contains(id)) {
        _selectedTagIds.remove(id);
        if (_selectedTagIds.isEmpty) _exitBatchMode();
      } else {
        _selectedTagIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final td = themeProvider.currentThemeData;
    final fp = themeProvider.currentFontPairData;
    final tags = themeProvider.tagColors;

    final canDelete = tags.length > EntryTags.minTags;
    final canAdd = tags.length < EntryTags.maxTags;
    final isModified = _isModifiedFromDefaults(tags);

    return PopScope(
      canPop: !_isBatchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _selectedTagIds.clear();
          _isBatchMode = false;
        });
      },
      child: Scaffold(
        backgroundColor: td.background,
        appBar: _isBatchMode ? _batchAppBar(td, fp, tags) : _normalAppBar(td, fp, canDelete),
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            _SectionRow(label: 'Tags (${tags.length}/${EntryTags.maxTags})'),
            _Card(
              children: [
                for (var i = 0; i < tags.length; i++) ...[
                  if (i > 0) _RowDivider(),
                  _TagRow(
                    tag: tags[i],
                    batchMode: _isBatchMode,
                    isSelected: _selectedTagIds.contains(tags[i].id),
                    onEdit: () => _showTagEditor(tags[i]),
                    onDelete: (canDelete && !_isBatchMode) ? () => _deleteTag(tags[i]) : null,
                    onToggleSelected: () => _toggleTagSelected(tags[i].id),
                    onLongPress: canDelete ? () => _enterBatchMode(tags[i].id) : null,
                  ),
                ],
              ],
            ),
            if (!_isBatchMode && canAdd) ...[
              const _SectionRow(label: 'Add'),
              _Card(
                children: [_AddRow(onTap: _addNewTag)],
              ),
            ],
            if (!_isBatchMode && isModified) ...[
              const _SectionRow(label: 'Reset'),
              _Card(
                children: [_ResetRow(onTap: () => _resetToDefaults())],
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Text(
                !_isBatchMode
                    ? 'Tap tags to edit them, or long-press a tag to start selecting.'
                    : 'Colour strips on journal entries update immediately. '
                    'Changes sync to the cloud when you\'re online.',
                style: AppTextStyles.labelLargeSans(td.textSecondary, fp)
                    .copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _normalAppBar(PoppyThemeData t, FontPairData fp, bool canDelete) {
    return AppBar(
      backgroundColor: t.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(AppIcons.back, size: AppIconSize.xs, color: t.textSecondary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text('Entry Tags', style: AppTextStyles.titleLarge(t.textPrimary, fp)),
    );
  }

  AppBar _batchAppBar(PoppyThemeData t, FontPairData fp, List<TagColorData> tags) {
    return AppBar(
      actionsPadding: const EdgeInsets.all(AppSpacing.sm),
      backgroundColor: t.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(AppIcons.close, color: t.textSecondary, size: AppIconSize.sm),
        onPressed: _exitBatchMode,
      ),
      title: Text('${_selectedTagIds.length} selected',
          style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      actions: [
        IconButton(
          tooltip: 'Select All',
          onPressed: () {
            setState(() {
              if (_selectedTagIds.length == tags.length) {
                _selectedTagIds.clear();
              } else{
                _selectedTagIds
                  ..clear()
                  ..addAll(tags.map((e) => e.id));
              }
            });
          },
          icon:
          Icon(AppIcons.checkCircle, color: t.accent, size: AppIconSize.sm),
        ),
        IconButton(
          icon: const Icon(AppIcons.delete, color: AppColors.error, size: AppIconSize.sm),
          tooltip: 'Delete selected tags',
          onPressed: _selectedTagIds.isEmpty ? null : () => _deleteBatch(tags),
        ),
      ],
    );
  }

  void _addNewTag() {
    final newTag = TagColorData(
      name: 'New Tag',
      color: AppColors.colorPalette[0],
      id: 'custom_${_uuid.v4().substring(0, 8)}',
      isBuiltIn: false,
    );
    _showTagEditor(newTag, isNew: true);
  }

  void _showTagEditor(TagColorData tag, {bool isNew = false}) {
    final nameCtrl = TextEditingController(text: tag.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ColorPickerSheet(
        title: isNew ? 'New Tag' : 'Edit Tag',
        description: 'Choose a name and colour',
        initialColor: tag.color,
        applyLabel: isNew ? 'Create Tag' : 'Save Changes',
        showCancel: true,
        showReset: false,
        onApply: (color) {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return false;

          final themeProvider = context.read<ThemeProvider>();
          final authProvider = context.read<AuthProvider>();
          final entriesProvider = context.read<EntriesProvider>();
          final currentTags =
          List<TagColorData>.from(themeProvider.tagColors);

          final isModifiedBuiltIn = tag.isBuiltIn && (tag.name != name || tag.color.toARGB32() != color.toARGB32());

          final updatedTag = TagColorData(
            name: name,
            color: color,
            id: isModifiedBuiltIn
                ? 'custom_${_uuid.v4().substring(0, 8)}'
                : tag.id,
            isBuiltIn: isModifiedBuiltIn ? false : tag.isBuiltIn,
          );

          if (isNew) {
            setState(() {
              currentTags.add(updatedTag);
              themeProvider.setTagColors(currentTags);
              themeProvider.pushTheme(authProvider.updateProfile);
            });
          } else {
            final index = currentTags.indexWhere((t) => t.id == tag.id);
            if (index != -1) currentTags[index] = updatedTag;
            setState(() {
              themeProvider.setTagColors(currentTags);
              entriesProvider.propagateTagEdit(tag, updatedTag);
              themeProvider.pushTheme(authProvider.updateProfile);
            });
            if (context.mounted) {
              final affected = entriesProvider.entries
                  .where((e) => e.colorTag.id == tag.id)
                  .length;
              if (affected > 0) {
                PoppySnackbar.success(
                  context,
                  '$affected ${affected == 1 ? 'entry' : 'entries'} updated.',
                );
              }
            }
          }
          return true;
        },
        extraFields: (ctx) {
          final t = ctx.poppyTheme;
          final fp = ctx.read<ThemeProvider>().currentFontPairData;
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameCtrl,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyMedium(t.textPrimary, fp),
                  decoration: InputDecoration(
                    labelText: 'Tag Name',
                    filled: true,
                    fillColor: t.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: hasText ? t.border : AppColors.error,
                        width: AppStroke.hairline,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: hasText ? t.border : AppColors.error,
                        width: AppStroke.hairline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: hasText ? t.accent : AppColors.error,
                        width: AppStroke.medium,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteTag(TagColorData tag) async {
    final themeProvider = context.read<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final entriesProvider = context.read<EntriesProvider>();

    final affectedCount =
        entriesProvider.entries.where((e) => e.colorTag.id == tag.id).length;

    final fallback = themeProvider.tagColors
        .firstWhere((t) => t.id != tag.id,
        orElse: () => EntryTags.defaultColor);

    final confirm = await PoppyDialog.showDestructive(
      context,
      title: 'Delete "${tag.name}"?',
      message: 'This cannot be undone.',
      body: affectedCount > 0
          ? DialogInfoBanner(
        icon: AppIcons.warning,
        tone: DialogBannerTone.warning,
        text: '$affectedCount ${affectedCount == 1 ? 'entry uses' : 'entries use'} this tag. They will fall back to "${fallback.name}".',
      )
          : null,
    );

    if (confirm != true || !mounted) return;

    final currentTags = List<TagColorData>.from(themeProvider.tagColors);
    if (currentTags.length <= EntryTags.minTags) return;

    currentTags.removeWhere((t) => t.id == tag.id);
    themeProvider.setTagColors(currentTags);
    await entriesProvider.propagateTagDeletion(tag, fallback);
    themeProvider.pushTheme(authProvider.updateProfile);

    if (mounted && affectedCount > 0) {
      PoppySnackbar.info(context,
          '$affectedCount ${affectedCount == 1 ? 'entry' : 'entries'} moved to "${fallback.name}".');
    }
  }

  Future<void> _deleteBatch(List<TagColorData> tags) async {
    final themeProvider = context.read<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final entriesProvider = context.read<EntriesProvider>();

    final toDelete = tags.where((t) => _selectedTagIds.contains(t.id)).toList();
    if (toDelete.isEmpty) return;

    final remaining = tags.where((t) => !_selectedTagIds.contains(t.id)).toList();

    if (remaining.length < EntryTags.minTags) {
      PoppySnackbar.warning(
        context,
        'You need at least ${EntryTags.minTags} tags. Deselect some and try again.',
      );
      return;
    }

    final affectedCount = entriesProvider.entries
        .where((e) => _selectedTagIds.contains(e.colorTag.id))
        .length;

    final count = toDelete.length;
    final confirm = await PoppyDialog.showDestructive(
      context,
      title: 'Delete $count ${count == 1 ? 'tag' : 'tags'}?',
      message: 'This cannot be undone.',
      body: affectedCount > 0
          ? DialogInfoBanner(
        icon: AppIcons.warning,
        tone: DialogBannerTone.warning,
        text: '$affectedCount ${affectedCount == 1 ? 'entry uses' : 'entries use'} these tags and will fall back to another tag.',
      )
          : null,
    );

    if (confirm != true || !mounted) return;

    final fallback = remaining.firstWhere(
          (t) => t.id == EntryTags.defaultColor.id,
      orElse: () => remaining.first,
    );

    for (final tag in toDelete) {
      await entriesProvider.propagateTagDeletion(tag, fallback);
    }

    themeProvider.setTagColors(remaining);
    themeProvider.pushTheme(authProvider.updateProfile);

    if (mounted) {
      _exitBatchMode();
      if (affectedCount > 0) {
        PoppySnackbar.info(context,
            '$affectedCount ${affectedCount == 1 ? 'entry' : 'entries'} moved to "${fallback.name}".');
      } else {
        PoppySnackbar.success(context, '$count ${count == 1 ? 'tag' : 'tags'} deleted.');
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final themeProvider = context.read<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final entriesProvider = context.read<EntriesProvider>();

    final currentTags = themeProvider.tagColors;
    const defaults = EntryTags.defaults;

    final removedTags = currentTags
        .where((t) => defaults.every((d) => d.id != t.id))
        .toList();

    final changedTags = currentTags.where((t) {
      final def = defaults.firstWhere((d) => d.id == t.id,
          orElse: () => t);
      return def.id == t.id &&
          (def.name != t.name || def.color.value != t.color.value);
    }).toList();

    final totalAffected = entriesProvider.entries
        .where((e) =>
    removedTags.any((r) => r.id == e.colorTag.id) ||
        changedTags.any((c) => c.id == e.colorTag.id))
        .length;

    final confirm = await PoppyDialog.showDestructive(
      context,
      title: 'Reset to defaults?',
      message: 'All custom tags will be removed and built-in tags will be restored.',
      body: totalAffected > 0
          ? DialogInfoBanner(
        icon: AppIcons.warning,
        tone: DialogBannerTone.warning,
        text: '$totalAffected ${totalAffected == 1 ? 'entry' : 'entries'} will be updated.',
      )
          : null,
    );

    if (confirm != true || !mounted) return;

    for (final removed in removedTags) {
      await entriesProvider.propagateTagDeletion(
          removed, EntryTags.defaultColor);
    }

    for (final changed in changedTags) {
      final def = defaults.firstWhere((d) => d.id == changed.id);
      await entriesProvider.propagateTagEdit(changed, def);
    }

    themeProvider.setTagColors(List.from(defaults));
    themeProvider.pushTheme(authProvider.updateProfile);

    if (mounted) {
      PoppySnackbar.success(context, 'Tags reset to defaults.');
    }
  }
}

class _SectionRow extends StatelessWidget {
  final String label;
  const _SectionRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final fp = themeProvider.currentFontPairData;
    final t = context.poppyTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        label,
        style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Divider(
      height: AppStroke.hairline,
      thickness: AppStroke.hairline,
      color: t.border,
      indent: AppSpacing.md + 32 + AppSpacing.md,
    );
  }
}

class _TagRow extends StatelessWidget {
  final TagColorData tag;
  final bool batchMode;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onToggleSelected;
  final VoidCallback? onLongPress;

  const _TagRow({
    required this.tag,
    required this.batchMode,
    required this.isSelected,
    required this.onEdit,
    this.onDelete,
    required this.onToggleSelected,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final themeProvider = context.read<ThemeProvider>();
    final fp = themeProvider.currentFontPairData;

    return InkWell(
      onTap: batchMode ? onToggleSelected : onEdit,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            _TagSwatch(color: tag.color, batchMode: batchMode, isSelected: isSelected),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Row(
                children: [
                  Text(tag.name,
                      style: AppTextStyles.titleSmallSans(t.textPrimary, fp)),
                  if (tag.isBuiltIn) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: t.accentLight,
                          borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Text('built-in',
                          style: AppTextStyles.labelSmall(t.accent, fp)
                              .copyWith(fontSize: 9)),
                    ),
                  ],
                ],
              ),
            ),
            if (!batchMode && onDelete != null) ...[
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onDelete,
                child: Icon(AppIcons.delete,
                    size: AppIconSize.xs,
                    color: AppColors.error.withValues(alpha: 0.5)),
              ),
            ] else if (batchMode)...[
              if (batchMode)
                AnimatedContainer(
                  duration: AppDuration.fast,
                  width: AppIconSize.sm,
                  height: AppIconSize.sm,
                  decoration: BoxDecoration(
                    color: isSelected ? t.accent : t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: isSelected ? t.accent : t.border,
                      width: AppStroke.thin,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(AppIcons.check,
                      size: AppIconSize.sm * 0.65, color: AppColors.white)
                      : null,
                ),

            ]
          ],
        ),
      ),
    );
  }
}

class _TagSwatch extends StatelessWidget {
  final Color color;
  final bool batchMode;
  final bool isSelected;

  const _TagSwatch({
    required this.color,
    required this.batchMode,
    required this.isSelected,
  });

  static const double _size = 26;

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    const ringSize = _size + 6;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: AppDuration.fast,
          width: ringSize,
          height: ringSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? t.accent : Colors.transparent,
              width: AppSpacing.xxs,
            ),
          ),
        ),
        Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            color: color,
            border: Border.all(color: t.border, width: AppStroke.hairline),
          ),
        ),
      ],
    );
  }
}

class _AddRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final themeProvider = context.read<ThemeProvider>();
    final fp = themeProvider.currentFontPairData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.5),
                        width: AppStroke.thin),
                  ),
                  child: Icon(AppIcons.add,
                      size: 14, color: t.accent.withValues(alpha: 0.8)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Add new tag',
                style: AppTextStyles.titleSmallSans(t.accent, fp)),
            const Spacer(),
            Icon(AppIcons.chevronRight,
                size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ResetRow extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final themeProvider = context.read<ThemeProvider>();
    final fp = themeProvider.currentFontPairData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    color: AppColors.errorLight,
                  ),
                  child: Icon(AppIcons.retry,
                      size: 13,
                      color: AppColors.error.withValues(alpha: 0.8)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset to defaults',
                      style: AppTextStyles.titleSmallSans(
                          AppColors.error, fp)),
                  Text('Restore built-in tags and remove custom ones',
                      style: AppTextStyles.labelLargeSans(
                          t.textTertiary, fp)
                          .copyWith(fontSize: 11)),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight,
                size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}