import 'package:flutter/material.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Color Dot Widget
//  Location: lib/core/widgets/color_dot.dart
// ─────────────────────────────────────────────────────────────

class ColorDot extends StatelessWidget {
  final EntryColorData colorData;
  final bool isSelected;
  final double size;
  final VoidCallback? onTap;

  const ColorDot({
    super.key,
    required this.colorData,
    this.isSelected = false,
    this.size = AppComponentSize.colorDot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: AppDuration.fast,
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorData.color as Color,
        border: isSelected
            ? Border.all(
          color: (Colors.black).withOpacity(0.35),
          width: AppStroke.thick,
        )
            : null,
      ),
    );

    if (onTap == null) return dot;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, 0, 0),
        child: dot,
      ),
    );
  }
}