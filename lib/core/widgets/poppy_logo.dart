import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

/// A custom-painted logo widget representing the Poppy brand identity.
///
/// The logo consists of a four-petal bloom with a central stamen dot.
/// It is drawn using vector paths to ensure sharpness at any scale.
class PoppyLogo extends StatelessWidget {
  /// The width and height of the logo square.
  final double size;

  /// The color of the logo petals. If null, defaults to the theme's accent color.
  final Color? color;

  /// The background color of the logo container.
  final Color? background;

  /// The border radius of the background container.
  final double? borderRadius;

  const PoppyLogo({
    super.key,
    this.size = AppIconSize.logo,
    this.color,
    this.background,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final inkColor = color ?? t.accent;
    final bgColor = background ?? t.background;

    Widget mark = CustomPaint(
      size: Size.square(size),
      painter: _PoppyMarkPainter(
        ink: inkColor,
        bg: bgColor,
      ),
    );

    if (bgColor != null) {
      final r = borderRadius ?? size * 0.24;
      mark = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(r),
        ),
        child: mark,
      );
    }

    return mark;
  }
}

/// A [CustomPainter] that renders the vector-based Poppy logo mark.
class _PoppyMarkPainter extends CustomPainter {
  final Color ink;
  final Color bg;

  const _PoppyMarkPainter({required this.ink, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // --- Proportions ---
    final r = cx * 0.72; // Petal half-length.
    final pw = cx * 0.50; // Petal half-width.
    final vr = cx * 0.30; // Centre void radius.
    final sr = cx * 0.11; // Stamen dot radius.

    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(cx, cy);

    // Creates a vesica (petal) shape.
    Path vesica() {
      return Path()
        ..moveTo(0, -r)
        ..cubicTo(pw, -r, pw, r, 0, r)
        ..cubicTo(-pw, r, -pw, -r, 0, -r)
        ..close();
    }

    // --- Petals ---
    canvas.save();
    canvas.rotate(math.pi / 4);
    canvas.drawPath(vesica(), paint);
    canvas.restore();

    canvas.save();
    canvas.rotate(3 * math.pi / 4);
    canvas.drawPath(vesica(), paint);
    canvas.restore();

    // --- Centre Details ---

    // Centre void punch.
    canvas.drawCircle(
        Offset.zero,
        vr,
        Paint()
          ..color = bg == Colors.transparent ? ink.withOpacity(0) : bg
          ..style = PaintingStyle.fill
          ..blendMode = bg == Colors.transparent ? BlendMode.clear : BlendMode.srcOver
          ..isAntiAlias = true);

    // Stamen dot.
    canvas.drawCircle(Offset.zero, sr, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PoppyMarkPainter old) => old.ink != ink || old.bg != bg;
}
