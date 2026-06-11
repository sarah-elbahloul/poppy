import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:poppy/core/widgets/color_dot.dart';

/// A horizontal selector for assigning a color tag (mood/category) to a journal entry.
///
/// Displays a label and a row of available [EntryColorData] options as interactive dots.
class ColorTagPicker extends StatelessWidget {
  /// The currently selected color tag.
  final EntryColorData selected;

  /// Callback triggered when a new color tag is selected.
  final ValueChanged<EntryColorData> onSelected;

  const ColorTagPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return Row(
      children: [
        Text(
          'Tag',
          style: AppTextStyles.labelLargeSerif(t.textTertiary, fp),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: EntryColors.all
                  .map((colorData) => ColorDot(
                colorData: colorData,
                isSelected: selected.id == colorData.id,
                size: AppComponentSize.colorDotPicker,
                onTap: () => onSelected(colorData),
              ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}