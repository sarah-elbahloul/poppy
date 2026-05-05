import 'package:flutter/material.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/color_dot.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Color Tag Picker Widget
//  Location: lib/core/widgets/color_tag_picker.dart
//
//  A horizontal row of color dots shown at the bottom of
//  the write screen. Tapping a dot selects it as the
//  entry's color tag.
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceLG,
        vertical: kSpaceSM,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(color: t.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Label
          Text(
            'Tag',
            style: TextStyle(
              fontSize: 11,
              color: t.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: kSpaceMD),

          // Dots
          ...EntryColors.all.map((colorData) {
            return ColorDot(
              colorData: colorData,
              isSelected: selected.id == colorData.id,
              size: 18,
              onTap: () => onSelected(colorData),
            );
          }),
        ],
      ),
    );
  }
}