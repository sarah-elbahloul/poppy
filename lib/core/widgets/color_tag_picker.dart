import 'package:flutter/material.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/color_dot.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Color Tag Picker
//  Location: lib/core/widgets/color_tag_picker.dart
// ─────────────────────────────────────────────────────────────

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
    final t = context.poppyTheme;

    return Row(
      children: [
        Text(
          'Tag',
          style: AppTextStyles.labelLargeSerif(t.textTertiary),
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