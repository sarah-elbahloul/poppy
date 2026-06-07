import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

/// Poppy — Logo mark
///
/// A custom-painted logo representing a four-petal bloom. 
/// Designed to be recognizable at any size and stable in various crops.
class PoppyLogo extends StatelessWidget {
  final double  size;
  final Color?  color;
  final Color?  background;
  final double? borderRadius;

  const PoppyLogo({
    super.key,
    this.size       = AppIconSize.logo,
    this.color,
    this.background,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final t       = context.poppyTheme;
    final inkColor = color ?? t.accent;
    final bgColor  = background ?? t.background;

    Widget mark = CustomPaint(
      size: Size.square(size),
      painter: _PoppyMarkPainter(
        ink: inkColor,
        bg:  bgColor,
      ),
    );

    if (bgColor != null) {
      final r = borderRadius ?? size * 0.24;
      mark = Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(r),
        ),
        child: mark,
      );
    }

    return mark;
  }
}

/// Internal painter for the Poppy logo mark.
class _PoppyMarkPainter extends CustomPainter {
  final Color ink;
  final Color bg;

  const _PoppyMarkPainter({required this.ink, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // Proportions for the logo elements.
    final r  = cx * 0.72;   // Petal half-length.
    final pw = cx * 0.50;   // Petal half-width.
    final vr = cx * 0.30;   // Centre void radius.
    final sr = cx * 0.11;   // Stamen dot radius.

    final paint = Paint()
      ..color     = ink
      ..style     = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(cx, cy);

    // Helper to create a vesica (petal) shape.
    Path vesica() {
      return Path()
        ..moveTo(0, -r)
        ..cubicTo( pw, -r,  pw,  r,  0,  r)
        ..cubicTo(-pw,  r, -pw, -r,  0, -r)
        ..close();
    }

    // Draw petals at 45 and 135 degrees.
    canvas.save();
    canvas.rotate(math.pi / 4);
    canvas.drawPath(vesica(), paint);
    canvas.restore();

    canvas.save();
    canvas.rotate(3 * math.pi / 4);
    canvas.drawPath(vesica(), paint);
    canvas.restore();

    // Centre void punch.
    canvas.drawCircle(Offset.zero, vr, Paint()
      ..color = bg == Colors.transparent ? ink.withOpacity(0) : bg
      ..style = PaintingStyle.fill
      ..blendMode = bg == Colors.transparent ? BlendMode.clear : BlendMode.srcOver
      ..isAntiAlias = true);

    // Stamen dot.
    canvas.drawCircle(Offset.zero, sr, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PoppyMarkPainter old) =>
      old.ink != ink || old.bg != bg;
}
