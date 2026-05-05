import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:poppy/core/theme/themes.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Logo Widget
//  Location: lib/core/widgets/poppy_logo.dart
//
//  Draws the Poppy flower mark in pure Flutter canvas.
//  Six petals arranged radially around a dark centre.
//  Uses the current theme accent color for petals.
// ─────────────────────────────────────────────────────────────

class PoppyLogo extends StatelessWidget {
  final double size;

  /// If true uses the full accent color — for splash / lock screens.
  /// If false uses the muted accent — for nav bars / small sizes.
  final bool prominent;

  const PoppyLogo({
    super.key,
    this.size = 48,
    this.prominent = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return CustomPaint(
      size: Size(size, size),
      painter: _PoppyPainter(
        petalColor: prominent ? t.accent : t.accentMuted,
        centreColor: const Color(0xFF2D1B0E),
        highlightColor: const Color(0xFF6B3F20),
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

    // ── Petal shape (same for all, like SVG) ──
    final petalRect = Rect.fromCenter(
      center: Offset(0, -r * 0.35), // shift upward like SVG (cy=20 vs 32)
      width: r * 0.6,
      height: r * 0.9,
    );

    // ── Light petals (background layer) ──
    final lightPaint = Paint()
      ..color = petalColor.withOpacity(0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

    final darkPaint = Paint()
      ..color = petalColor.withOpacity(0.65)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

    // Move to center once
    canvas.translate(cx, cy);

    // Draw light petals: 0, 60, 120
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3); // 60°
      canvas.drawOval(petalRect, lightPaint);
      canvas.restore();
    }

    // Draw dark petals: 30, 90, 150
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate((i * math.pi / 3) + (math.pi / 6)); // +30°
      canvas.drawOval(petalRect, darkPaint);
      canvas.restore();
    }

    // ── Centre circle ──
    final centrePaint = Paint()
      ..color = centreColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, r * 0.25, centrePaint);

    // ── Centre highlight dots ──
    final dotPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    final dots = [
      Offset(-r * 0.08, -r * 0.08),
      Offset(r * 0.1, -r * 0.05),
      Offset(-r * 0.02, r * 0.1),
    ];

    for (final d in dots) {
      canvas.drawCircle(d, r * 0.035, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PoppyPainter old) =>
      old.petalColor != petalColor ||
          old.centreColor != centreColor;
}