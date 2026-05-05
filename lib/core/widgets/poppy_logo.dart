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

    // ── Petals ─────────────────────────────────────────────
    // 6 petals: alternating two shades for depth.
    const petalCount = 6;
    final petalRadiusX = r * 0.38;
    final petalRadiusY = r * 0.52;
    final petalOffset = r * 0.28; // how far from centre

    for (int i = 0; i < petalCount; i++) {
      final angle = (i * math.pi * 2) / petalCount;
      final isOdd = i.isOdd;

      final paint = Paint()
        ..color = isOdd
            ? petalColor.withOpacity(0.85)
            : petalColor.withOpacity(0.65)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(
        cx + petalOffset * math.cos(angle),
        cy + petalOffset * math.sin(angle),
      );
      canvas.rotate(angle);

      final petalRect = Rect.fromCenter(
        center: Offset.zero,
        width: petalRadiusX * 2,
        height: petalRadiusY * 2,
      );
      canvas.drawOval(petalRect, paint);
      canvas.restore();
    }

    // ── Centre circle ──────────────────────────────────────
    final centrePaint = Paint()
      ..color = centreColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), r * 0.26, centrePaint);

    // ── Centre highlight dots ──────────────────────────────
    final dotPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    final dotPositions = [
      Offset(cx - r * 0.07, cy - r * 0.07),
      Offset(cx + r * 0.09, cy - r * 0.04),
      Offset(cx - r * 0.02, cy + r * 0.09),
    ];

    for (final pos in dotPositions) {
      canvas.drawCircle(pos, r * 0.035, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PoppyPainter old) =>
      old.petalColor != petalColor ||
          old.centreColor != centreColor;
}