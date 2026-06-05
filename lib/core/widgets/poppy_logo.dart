import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Logo mark
//  Location: lib/core/widgets/poppy_logo.dart
//
//  Design: four-petal bloom, each petal a vesica (lens) shape
//  rotated 45 ° and 135 °. The two rotated vesicas overlap at
//  the diagonals to produce a four-fold bloom. A large cream
//  void punches through the centre, with a small stamen dot.
//
//  The form is:
//    · Recognisable as a poppy at every size
//    · Stable in a rounded-square (app icon) or circle crop
//    · One colour + background — no gradients, no strokes
//    · Scales cleanly from 1024 px down to 16 px
//
//  Usage:
//    PoppyLogo(size: 80)               // accent on transparent
//    PoppyLogo(size: 80, background: t.surface)   // icon tile
//    PoppyLogo(size: 200, background: t.background) // splash
// ─────────────────────────────────────────────────────────────

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

class _PoppyMarkPainter extends CustomPainter {
  final Color ink;
  final Color bg;

  const _PoppyMarkPainter({required this.ink, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // Proportions tuned so the mark sits with generous padding
    // inside any container.  All values are fractions of `cx`.
    final r  = cx * 0.72;   // half-length of each petal (centre→tip)
    final pw = cx * 0.50;   // half-width of each petal at widest
    final vr = cx * 0.30;   // centre void radius
    final sr = cx * 0.11;   // stamen dot radius

    final paint = Paint()
      ..color     = ink
      ..style     = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(cx, cy);

    // ── Two vesica petals, each covers two opposing directions ──
    // Vesica path: starts at (0,-r), curves out to (±pw,0),
    // closes at (0,+r), curves back through (∓pw,0).
    Path _vesica() {
      return Path()
        ..moveTo(0, -r)
        ..cubicTo( pw, -r,  pw,  r,  0,  r)
        ..cubicTo(-pw,  r, -pw, -r,  0, -r)
        ..close();
    }

    // Petal pair A — rotated 45°
    canvas.save();
    canvas.rotate(math.pi / 4);
    canvas.drawPath(_vesica(), paint);
    canvas.restore();

    // Petal pair B — rotated 135° (perpendicular to A)
    canvas.save();
    canvas.rotate(3 * math.pi / 4);
    canvas.drawPath(_vesica(), paint);
    canvas.restore();

    // ── Centre void — punches a hole through the petals ────────
    canvas.drawCircle(Offset.zero, vr, Paint()
      ..color = bg == Colors.transparent
          ? (ink.withOpacity(0))   // let the container bg show
          : bg
      ..style = PaintingStyle.fill
      ..blendMode = bg == Colors.transparent
          ? BlendMode.clear
          : BlendMode.srcOver
      ..isAntiAlias = true);

    // ── Stamen dot ──────────────────────────────────────────────
    canvas.drawCircle(Offset.zero, sr, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PoppyMarkPainter old) =>
      old.ink != ink || old.bg != bg;
}