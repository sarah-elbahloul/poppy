import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:provider/provider.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';

/// How a [ColorTagSelector] lays out its options.
enum ColorTagSelectorLayout {
  /// A single horizontally-scrolling row. Used inline, e.g. in the write
  /// screen's metadata bar or the home screen's filter bar.
  scrollRow,

  /// A wrapping grid that lays out across multiple lines. Used in
  /// fixed-height containers like a bottom sheet, where horizontal
  /// scrolling isn't desirable.
  wrap,
}

/// A single, reusable color-tag picker used everywhere a journal entry's
/// color tag can be viewed or chosen: the write screen, the home screen's
/// filter bar, and the bulk-recolor bottom sheet.
///
/// Visual contract (the same everywhere this widget is used):
/// - Resting (unselected) dots are all the same size —
///   [AppComponentSize.colorDotPicker] — regardless of layout.
/// - A selected dot expands into a pill: a tinted background, a colored
///   border, and (optionally) the tag's name label next to it.
///
/// This intentionally merges what used to be three separately-styled
/// implementations (write screen's bordered-dot picker, home screen's
/// pill-style filter row, and the bottom sheet's plain dot grid) into one
/// widget with one visual language.
class ColorTagSelector extends StatelessWidget {
  /// The currently selected color tag, or null if none is selected.
  ///
  /// Pass null when used as a filter with nothing chosen yet (e.g. "All").
  final TagColorData? selected;

  /// Called with the tapped color when a new tag is chosen.
  ///
  /// If [allowDeselect] is true and the user taps the already-selected
  /// option, this is called with `null` instead of being skipped.
  final ValueChanged<TagColorData?> onSelected;

  /// Layout strategy — see [ColorTagSelectorLayout].
  final ColorTagSelectorLayout layout;

  /// Whether the selected option's name label appears next to its dot.
  /// Defaults to true, matching the original home-screen filter behavior.
  final bool showLabelOnSelect;

  /// Whether tapping the already-selected option clears the selection
  /// (calls [onSelected] with null). Useful for filter bars; typically off
  /// for pickers where some tag must always be chosen (e.g. the write
  /// screen, where an entry always has a color tag).
  final bool allowDeselect;

  /// Optional leading widget, e.g. a label or icon, placed before the dots.
  /// Only used with [ColorTagSelectorLayout.scrollRow].
  final Widget? leading;

  const ColorTagSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.layout = ColorTagSelectorLayout.scrollRow,
    this.showLabelOnSelect = true,
    this.allowDeselect = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    final options = EntryTags.all.map((colorData) {
      final isSelected = selected?.id == colorData.id;
      return Padding(
        padding: isSelected ? const EdgeInsets.symmetric(horizontal: AppSpacing.xs) : EdgeInsets.zero,
        child: Row(
          children: [
            _ColorTagOption(
              colorData: colorData,
              isSelected: isSelected,
              showLabelOnSelect: showLabelOnSelect,
              fp: fp,
              onTap: () {
                if (isSelected && allowDeselect) {
                  onSelected(null);
                } else {
                  onSelected(colorData);
                }
              },
            ),
            if (colorData == EntryTags.all.last)...[
              SizedBox(width: AppSpacing.xs)
            ]
          ],
        ),
      );
    }).toList();

    switch (layout) {
      case ColorTagSelectorLayout.scrollRow:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: options),
              ),
            ),
          ],
        );

      case ColorTagSelectorLayout.wrap:
        return Wrap(
          spacing: 0,
          runSpacing: 0,
          children: options,
        );
    }
  }
}

/// A single tappable dot/pill within a [ColorTagSelector].
///
/// Resting state: a plain dot at [AppComponentSize.colorDotPicker].
/// Selected state: the dot grows a tinted pill background, a colored
/// border, and (if [showLabelOnSelect]) the tag's name.
class _ColorTagOption extends StatelessWidget {
  final TagColorData colorData;
  final bool isSelected;
  final bool showLabelOnSelect;
  final FontPairData fp;
  final VoidCallback onTap;

  const _ColorTagOption({
    required this.colorData,
    required this.isSelected,
    required this.showLabelOnSelect,
    required this.fp,
    required this.onTap,
  });

  @override
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorData.color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? colorData.color : Colors.transparent,
            width: AppStroke.thin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppComponentSize.colorDotPicker,
              height: AppComponentSize.colorDotPicker,
              decoration: BoxDecoration(
                color: colorData.color,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            if (isSelected && showLabelOnSelect) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                colorData.name,
                style: AppTextStyles.labelLargeSans(colorData.color, fp),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }

}