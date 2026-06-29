import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/core/widgets/widgets.dart';
import 'package:poppy/providers/providers.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Tags Screen
//  Location: lib/screens/settings/entry_tags_screen.dart
// ─────────────────────────────────────────────────────────────

class EntryTagsScreen extends StatefulWidget {
  const EntryTagsScreen({super.key});

  @override
  State<EntryTagsScreen> createState() => _EntryTagsScreenState();
}

class _EntryTagsScreenState extends State<EntryTagsScreen> {
  final _uuid = const Uuid();

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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final td = themeProvider.currentThemeData;
    final fp = themeProvider.currentFontPairData;
    final tags = themeProvider.tagColors;

    final canDelete = tags.length > EntryTags.minTags;
    final canAdd = tags.length < EntryTags.maxTags;
    final isModified = _isModifiedFromDefaults(tags);

    return Scaffold(
      backgroundColor: td.background,
      appBar: AppBar(
        backgroundColor: td.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: td.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Entry Tags',
            style: AppTextStyles.titleLarge(td.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          _SectionLabel('Tags (${tags.length}/${EntryTags.maxTags})'),
          _Card(
            children: [
              for (var i = 0; i < tags.length; i++) ...[
                if (i > 0) _RowDivider(),
                _TagRow(
                  tag: tags[i],
                  onEdit: () => _showTagEditor(tags[i]),
                  onDelete: canDelete ? () => _deleteTag(tags[i]) : null,
                ),
              ],
            ],
          ),
          if (canAdd) ...[
            const _SectionLabel('Add'),
            _Card(
              children: [_AddRow(onTap: _addNewTag)],
            ),
          ],
          if (isModified) ...[
            const _SectionLabel('Reset'),
            _Card(
              children: [_ResetRow(onTap: () => _resetToDefaults())],
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Text(
              'Colour strips on journal entries update immediately. '
                  'Changes sync to the cloud when you\'re online.',
              style: AppTextStyles.labelLargeSans(td.textSecondary, fp)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
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
            currentTags.add(updatedTag);
            themeProvider.setTagColors(currentTags);
            themeProvider.pushTagColors(authProvider.updateProfile);
          } else {
            final index = currentTags.indexWhere((t) => t.id == tag.id);
            if (index != -1) currentTags[index] = updatedTag;

            themeProvider.setTagColors(currentTags);
            entriesProvider.propagateTagEdit(tag, updatedTag);
            themeProvider.pushTagColors(authProvider.updateProfile);

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
    themeProvider.pushTagColors(authProvider.updateProfile);

    if (mounted && affectedCount > 0) {
      PoppySnackbar.info(context,
          '$affectedCount ${affectedCount == 1 ? 'entry' : 'entries'} moved to "${fallback.name}".');
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
    themeProvider.pushTagColors(authProvider.updateProfile);

    if (mounted) {
      PoppySnackbar.success(context, 'Tags reset to defaults.');
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall(t.textTertiary, fp)
            .copyWith(letterSpacing: 0.8),
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
      indent: AppSpacing.md + 20 + AppSpacing.md,
    );
  }
}

class _TagRow extends StatelessWidget {
  final TagColorData tag;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _TagRow({
    required this.tag,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration:
              BoxDecoration(color: tag.color, shape: BoxShape.circle),
            ),
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
            if (onDelete != null) ...[
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onDelete,
                child: Icon(AppIcons.delete,
                    size: AppIconSize.xs,
                    color: AppColors.error.withValues(alpha: 0.5)),
              ),
            ] else
              const SizedBox(width: AppSpacing.xs + AppIconSize.xs),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                    color: t.accent.withValues(alpha: 0.5),
                    width: AppStroke.thin),
              ),
              child: Icon(AppIcons.add,
                  size: 12, color: t.accent.withValues(alpha: 0.8)),
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
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.errorLight,
              ),
              child: Icon(AppIcons.retry,
                  size: 11,
                  color: AppColors.error.withValues(alpha: 0.8)),
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
