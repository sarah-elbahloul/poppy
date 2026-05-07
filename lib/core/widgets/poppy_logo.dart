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
        petalColor:     prominent ? t.accent : t.accentMuted,
        centreColor:    AppColors.logoCentre,
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

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Move canvas origin to flower center
    canvas.translate(cx, cy);

    // Shared petal shape
    final petalRect = Rect.fromCenter(
      center: Offset(0, -r * 0.35),
      width: r * 0.7,
      height: r * 0.9,
    );

    // ── Light petals ───────────────────────────
    final lightPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          petalColor.withOpacity(0.8),
          petalColor.withOpacity(0.35),
        ],
      ).createShader(petalRect)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        0.4,
      );

    // ── Dark petals ────────────────────────────
    final darkPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          petalColor.withOpacity(1.0),
          petalColor.withOpacity(0.5),
        ],
      ).createShader(petalRect)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        0.4,
      );

    const petalCount = 10;

    for (int i = 0; i < petalCount; i++) {
      final angle = (i * 2 * math.pi) / petalCount;

      final paint = i.isEven
          ? darkPaint
          : lightPaint;

      canvas.save();
      canvas.rotate(angle);
      canvas.drawOval(petalRect, paint);
      canvas.restore();
    }

    // ── Centre circle ──────────────────────────
    final centrePaint = Paint()
      ..color = centreColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset.zero,
      r * 0.28,
      centrePaint,
    );

    // ── Highlight dots ─────────────────────────
    final dotPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    final dots = [
      Offset(-r * 0.10, -r * 0.08),
      Offset(r * 0.08, -r * 0.09),

      Offset(-r * 0.14, 0),
      Offset(r * 0.12, r * 0.02),

      Offset(-r * 0.05, r * 0.10),
      Offset(r * 0.05, r * 0.12),
    ];

    final sizes = [
      0.032,
      0.026,
      0.030,
      0.024,
      0.028,
      0.025,
    ];

    for (int i = 0; i < dots.length; i++) {
      canvas.drawCircle(
        dots[i],
        r * sizes[i],
        dotPaint,
      );
    }

    // Center highlight dot
    final centerDotPaint = Paint()
      ..color = highlightColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset.zero,
      r * 0.04,
      centerDotPaint,
    );
  }

  @override
  bool shouldRepaint(_PoppyPainter old) =>
      old.petalColor != petalColor || old.centreColor != centreColor;
}