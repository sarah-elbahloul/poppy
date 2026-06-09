import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';

/// A circular widget used to represent an [EntryColorData].
///
/// It can indicate selection with a border and is typically used in color pickers
/// or entry metadata displays.
class ColorDot extends StatelessWidget {
  /// The color metadata to represent.
  final EntryColorData colorData;

  /// Whether this color dot is currently selected.
  final bool isSelected;

  /// The diameter of the dot.
  final double size;

  /// Optional callback when the dot is tapped.
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorData.color,
        border: isSelected
            ? Border.all(
                color: Colors.black.withValues(alpha: 0.35),
                width: AppStroke.thick,
              )
            : null,
      ),
    );

    if (onTap == null) return dot;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: dot,
      ),
    );
  }
}
