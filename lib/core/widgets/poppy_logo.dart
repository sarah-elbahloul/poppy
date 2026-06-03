import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Logo Widget
//  Location: lib/core/widgets/poppy_logo.dart
// ─────────────────────────────────────────────────────────────

class PoppyLogo extends StatelessWidget {
  final double size;
  final bool prominent;

  const PoppyLogo({
    super.key,
    this.size = AppIconSize.logo,
    this.prominent = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return CustomPaint(
      size: Size(size, size),
      painter: _PoppyPainter(
        petalColor: prominent ? t.accent : t.accentMuted,
        centreColor: AppColors.logoCentre,
        highlightColor: AppColors.logoHighlight,
      ),
    );
  }
}

class _PoppyPainter extends CustomPainter {
  final Color petalColor;
  final Color centreColor;
  final Color highlightColor;

  const _PoppyPainter({
    required this.petalColor,
    required this.centreColor,
    required this.highlightColor,
  });

  /// Organic petal shape using cubic beziers — wider in the
  /// upper-middle, tapering softly to a rounded tip.
  Path _petalPath(double length, double width, {double drift = 0.0}) {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(
        -width * 0.65, -length * 0.25,
        -width * 0.55 + drift, -length * 0.72,
        0, -length,
      )
      ..cubicTo(
        width * 0.55 + drift, -length * 0.72,
        width * 0.65, -length * 0.25,
        0, 0,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.translate(cx, cy);

    // ── Warm ambient glow ──────────────────────
    final glow = Paint()
      ..color = petalColor.withOpacity(0.07)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5);
    canvas.drawCircle(Offset.zero, r * 0.95, glow);

    // ── Back petal layer (5, offset rotation) ──
    const backCount = 5;
    for (int i = 0; i < backCount; i++) {
      final angle = (i * 2 * math.pi) / backCount + math.pi / backCount;
      final path = _petalPath(r * 0.76, r * 0.40, drift: r * 0.025);

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = petalColor.withOpacity(0.22);

      canvas.save();
      canvas.rotate(angle);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // ── Front petal layer (5) ──────────────────
    const frontCount = 5;
    for (int i = 0; i < frontCount; i++) {
      final angle = (i * 2 * math.pi) / frontCount;
      final path = _petalPath(r * 0.66, r * 0.34, drift: -r * 0.012);

      // Gradient runs tip → base so the tip is richest
      final gradRect = Rect.fromCenter(
        center: Offset(0, -r * 0.33),
        width: r * 0.70,
        height: r * 0.66,
      );

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            petalColor.withOpacity(0.92),
            petalColor.withOpacity(0.58),
            petalColor.withOpacity(0.28),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(gradRect);

      canvas.save();
      canvas.rotate(angle);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // ── Soft shadow under centre ───────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(const Offset(0, 1.2), r * 0.19, shadowPaint);

    // ── Centre disc with subtle radial light ───
    final centreRadius = r * 0.18;
    final centreGrad = RadialGradient(
      center: const Alignment(-0.25, -0.25),
      radius: 0.8,
      colors: [
        centreColor.withOpacity(1.0),
        centreColor.withOpacity(0.75),
      ],
    );

    final centrePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = centreGrad.createShader(
        Rect.fromCircle(center: Offset.zero, radius: centreRadius),
      );

    canvas.drawCircle(Offset.zero, centreRadius, centrePaint);

    // ── Stamen dots (organic scatter) ──────────
    final rng = math.Random(42);
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 14; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final dist = rng.nextDouble() * r * 0.14;
      final dotR = r * (0.014 + rng.nextDouble() * 0.010);

      dotPaint.color = highlightColor.withOpacity(0.45 + rng.nextDouble() * 0.55);
      canvas.drawCircle(
        Offset(math.cos(a) * dist, math.sin(a) * dist),
        dotR,
        dotPaint,
      );
    }

    // Tiny bright centre dot
    dotPaint.color = highlightColor.withOpacity(0.85);
    canvas.drawCircle(Offset.zero, r * 0.028, dotPaint);
  }

  @override
  bool shouldRepaint(_PoppyPainter old) =>
      old.petalColor != petalColor || old.centreColor != centreColor;
}