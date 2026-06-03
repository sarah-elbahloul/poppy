import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';

class PoppyLogo extends StatelessWidget {
  final double size;
  final bool prominent;

  final Color? background;

  const PoppyLogo({
    super.key,
    this.size = AppIconSize.logo,
    this.prominent = true,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return CustomPaint(
      size: Size.square(size),
      painter: _PoppyLogoPainter(
        color: prominent ? t.accent : t.accentMuted,
        background: background,
      ),
    );
  }
}

class _PoppyLogoPainter extends CustomPainter {
  final Color color;
  final Color? background;

  const _PoppyLogoPainter({
    required this.color,
    this.background,
  });

  Path _petalShape(double length, double width) {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(
        -width, -length * 0.30,
        -width * 0.78, -length * 0.82,
        0, -length,
      )
      ..cubicTo(
        width * 0.78, -length * 0.82,
        width, -length * 0.30,
        0, 0,
      );
  }

  Path _nibShape(double height) {
    final w = height * 0.38;

    return Path()
      ..moveTo(0, height)
      ..quadraticBezierTo(
        -w * 0.55, height * 0.50,
        -w, -height * 0.28,
      )
      ..quadraticBezierTo(
        0, -height * 0.54,
        w, -height * 0.28,
      )
      ..quadraticBezierTo(
        w * 0.55, height * 0.50,
        0, height,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.35;

    canvas.save();
    canvas.translate(cx, cy);

    // Background
    if (background != null) {
      canvas.drawCircle(
        Offset.zero,
        size.width * 0.49,
        Paint()..color = background!,
      );
    }

    final petals = Path();
    const petalCount = 4;
    const sizeJitter = [0.00, 0.03, -0.018, 0.012];

    Path _rotatePath(Path path, double angle) {
      final m = Matrix4.identity()..rotateZ(angle);
      return path.transform(m.storage);
    }

    for (int i = 0; i < petalCount; i++) {
      final angle = (i * math.pi * 2 / petalCount) + math.pi / 4;

      final len = r * (0.97 + sizeJitter[i]);
      final wid = r * 0.40;

      final petal = _petalShape(len, wid);

      final rotated = _rotatePath(petal, angle);

      petals.addPath(rotated, Offset.zero);
    }

    final nib = _nibShape(r * 0.52);

    final mark = Path.combine(
      PathOperation.difference,
      petals,
      nib,
    );

    final paint = Paint()..color = color;
    canvas.drawPath(mark, paint);

    // Slit
    final slitW = math.max(0.8, r * 0.038);

    canvas.drawLine(
      Offset(0, -r * 0.10),
      Offset(0, r * 0.42),
      Paint()
        ..color = color
        ..strokeWidth = slitW
        ..strokeCap = StrokeCap.round,
    );

    // Hole
    final holeR = math.max(0.6, r * 0.032);

    canvas.drawCircle(
      Offset(0, -r * 0.08),
      holeR,
      Paint()..color = color,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PoppyLogoPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.background != background;
  }
}