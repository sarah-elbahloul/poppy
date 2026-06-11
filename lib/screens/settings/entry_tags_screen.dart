import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/core/widgets/color_picker_sheet.dart';
import 'package:poppy/providers/providers.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class EntryTagsScreen extends StatefulWidget {
  const EntryTagsScreen({super.key});

  @override
  State<EntryTagsScreen> createState() => _EntryTagsScreenState();
}

class _EntryTagsScreenState extends State<EntryTagsScreen> {
  final _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final td = themeProvider.currentThemeData;
    final fp = themeProvider.currentFontPairData;
    final tags = themeProvider.tagColors;

    final canDelete = tags.length > EntryColors.minTags;
    final canAdd = tags.length < EntryColors.maxTags;

    return Scaffold(
      backgroundColor: td.background,
      appBar: AppBar(
        backgroundColor: td.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: td.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Entry Tags',
            style: AppTextStyles.titleLarge(td.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Customise the color strips that appear on your journal entries. You must have between ${EntryColors.minTags} and ${EntryColors.maxTags} tags.',
            style: AppTextStyles.bodySmallSans(td.textSecondary, fp),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...tags.map((tag) => _TagTile(
            tag: tag,
            onEdit: () => _showTagEditor(tag),
            onDelete: canDelete ? () => _deleteTag(tag) : null,
          )),
          if (canAdd) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _addNewTag,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: td.border),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: Icon(AppIcons.add, size: AppIconSize.xs, color: td.accent),
              label: Text('Add new tag',
                  style: AppTextStyles.titleSmallSans(td.accent, fp)),
            ),
          ],
        ],
      ),
    );
  }

  void _addNewTag() {
    final newTag = EntryColorData(
      name: 'New Tag',
      color: AppColors.colorPalette[0],
      id: 'custom_${_uuid.v4().substring(0, 8)}',
      isBuiltIn: false,
    );
    _showTagEditor(newTag, isNew: true);
  }

  void _showTagEditor(EntryColorData tag, {bool isNew = false}) {
    final nameCtrl = TextEditingController(text: tag.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

          final currentTags = List<EntryColorData>.from(themeProvider.tagColors);
          final updatedTag = EntryColorData(
            name: name,
            color: color,
            id: tag.id,
            isBuiltIn: tag.isBuiltIn,
          );

          if (isNew) {
            currentTags.add(updatedTag);
          } else {
            final index =
            currentTags.indexWhere((t) => t.id == tag.id);
            if (index != -1) currentTags[index] = updatedTag;
          }

          themeProvider.setTagColors(currentTags);
          authProvider.updateProfileTags(currentTags);
          return true;
        },
        extraFields: (ctx) {
          final t = ctx.poppyTheme;
          final fp = ctx.read<ThemeProvider>().currentFontPairData;

          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.bodyMedium(t.textPrimary, fp),
              decoration: InputDecoration(
                labelText: 'Tag Name',
                filled: true,
                fillColor: t.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: t.accent, width: AppStroke.medium),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteTag(EntryColorData tag) async {
    final themeProvider = context.read<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final td = themeProvider.currentThemeData;
    final fp = themeProvider.currentFontPairData;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: td.surface,
        title: Text('Delete Tag?',
            style: AppTextStyles.headlineSmall(td.textPrimary, fp)),
        content: Text(
          'Any entries using this tag will fallback to the default color. This cannot be undone.',
          style: AppTextStyles.bodySmallSans(td.textSecondary, fp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: td.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
            const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentTags = List<EntryColorData>.from(themeProvider.tagColors);
      if (currentTags.length <= EntryColors.minTags) return;

      currentTags.removeWhere((t) => t.id == tag.id);
      themeProvider.setTagColors(currentTags);
      authProvider.updateProfileTags(currentTags);
    }
  }
}

class _TagTile extends StatelessWidget {
  final EntryColorData tag;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _TagTile({required this.tag, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final td = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: td.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: td.border, width: AppStroke.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: tag.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(tag.name,
                style: AppTextStyles.titleSmallSans(td.textPrimary, fp)),
          ),
          IconButton(
            icon: Icon(AppIcons.edit,
                size: AppIconSize.xs, color: td.textTertiary),
            onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(AppIcons.delete,
                  size: AppIconSize.xs,
                  color: AppColors.error.withValues(alpha: 0.5)),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
