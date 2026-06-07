import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:poppy/core/widgets/color_dot.dart';

/// A horizontal picker for choosing an [EntryColorData] tag.
///
/// Displays a label and a row of [ColorDot] widgets representing 
/// the available entry colors.
class ColorTagPicker extends StatelessWidget {
  final EntryColorData selected;
  final ValueChanged<EntryColorData> onSelected;

  const ColorTagPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return Row(
      children: [
        Text(
          'Tag',
          style: AppTextStyles.labelLargeSerif(t.textTertiary, fp),
        ),
        ...EntryColors.all.map((colorData) => ColorDot(
          colorData:  colorData,
          isSelected: selected.id == colorData.id,
          size:       AppComponentSize.colorDotPicker,
          onTap:      () => onSelected(colorData),
        )),
      ],
    );
  }
}
