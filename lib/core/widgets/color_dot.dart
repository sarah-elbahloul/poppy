import 'package:flutter/material.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Color Dot Widget
//  Location: lib/core/widgets/color_dot.dart
//
//  Small filled circle representing an entry color tag.
//  Used in the search screen color filter row and anywhere
//  else a color needs to be represented as a dot.
// ─────────────────────────────────────────────────────────────

class ColorDot extends StatelessWidget {
  final EntryColorData colorData;

  /// If true, draws a thin ring around the dot to show
  /// it is the currently selected tag.
  final bool isSelected;

  /// Dot diameter. Defaults to 20.
  final double size;

  /// Optional tap handler — if null the dot is not tappable.
  final VoidCallback? onTap;

  const ColorDot({
    super.key,
    required this.colorData,
    this.isSelected = false,
    this.size = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: kAnimFast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorData.color,
        border: isSelected
            ? Border.all(
          color: colorData.color.withOpacity(0.35),
          width: 3,
        )
            : null,
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: colorData.color.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
    );

    if (onTap == null) return dot;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        // Extra tap area around the small dot
        padding: const EdgeInsets.all(kSpaceSM),
        child: dot,
      ),
    );
  }
}