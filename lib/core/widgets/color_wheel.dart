import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/core/style/style.dart';

/// A custom color wheel widget for selecting HSL colors.
///
/// It consists of an outer hue ring and an inner saturation/lightness circle.
class ColorWheel extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;
  final double size;

  const ColorWheel({
    super.key,
    required this.initialColor,
    required this.onChanged,
    this.size = 240,
  });

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  late double _hue;
  late double _saturation;
  late double _lightness;

  bool _isDraggingHue = false;
  bool _isDraggingInner = false;

  static const double _ringWidth = AppSpacing.lg;
  static const double _spacing = AppSpacing.lg;

  @override
  void initState() {
    super.initState();
    _syncFromColor(widget.initialColor);
  }

  @override
  void didUpdateWidget(ColorWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialColor.value != oldWidget.initialColor.value &&
        !_isDraggingHue && !_isDraggingInner) {
      _syncFromColor(widget.initialColor);
    }
  }

  void _syncFromColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    // Clamp lightness slightly away from extremes to keep the indicator visible and movable.
    _lightness = hsl.lightness.clamp(0.01, 0.99);
  }

  Color get _current {
    return HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();
  }

  void _handleInteraction(Offset localPos, {bool isStart = false}) {
    final center = widget.size / 2;
    final dx = localPos.dx - center;
    final dy = localPos.dy - center;
    final dist = math.sqrt(dx * dx + dy * dy);

    final innerR = center - _ringWidth - _spacing;

    if (isStart) {
      // Forgiving hit detection for the hue ring vs inner circle.
      if (dist >= innerR + (_spacing / 2)) {
        _isDraggingHue = true;
        _isDraggingInner = false;
        HapticFeedback.selectionClick();
      } else {
        _isDraggingInner = true;
        _isDraggingHue = false;
      }
    }

    if (_isDraggingHue) {
      var angle = math.atan2(dy, dx) * 180 / math.pi;
      if (angle < 0) angle += 360;

      // Haptic feedback for significant changes.
      if ((angle - _hue).abs() > 5) {
        HapticFeedback.selectionClick();
      }
      setState(() => _hue = angle);
    } else if (_isDraggingInner) {
      // Map circle coordinates to Saturation and Lightness.
      final clampedDist = dist.clamp(0.0, innerR);
      final angle = math.atan2(dy, dx);

      final px = clampedDist * math.cos(angle);
      final py = clampedDist * math.sin(angle);

      setState(() {
        // Horizontal axis: Saturation (0 to 1).
        _saturation = ((px / innerR) + 1) / 2;
        // Vertical axis: Lightness (1 to 0).
        _lightness = 1.0 - ((py / innerR) + 1) / 2;
      });
    }

    if (_isDraggingHue || _isDraggingInner) {
      widget.onChanged(_current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.size / 2;
    final innerR = center - _ringWidth - _spacing;

    final hueRad = _hue * math.pi / 180;
    final hueRadius = center - _ringWidth / 2;

    final hueDotPos = Offset(
      center + hueRadius * math.cos(hueRad),
      center + hueRadius * math.sin(hueRad),
    );

    final satLightDotPos = Offset(
      center + (_saturation * 2 - 1) * innerR,
      center + ((1 - _lightness) * 2 - 1) * innerR,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _handleInteraction(d.localPosition, isStart: true),
      onPanUpdate: (d) => _handleInteraction(d.localPosition),
      onPanEnd: (_) => setState(() {
        _isDraggingHue = false;
        _isDraggingInner = false;
      }),
      onTapDown: (d) => _handleInteraction(d.localPosition, isStart: true),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Hue Ring.
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _HueRingPainter(ringWidth: _ringWidth),
            ),

            // Saturation/Lightness Inner Circle.
            Center(
              child: Container(
                width: innerR * 2,
                height: innerR * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  clipBehavior: Clip.antiAlias,
                  child: CustomPaint(
                    painter: _SatLightPainter(hue: _hue),
                  ),
                ),
              ),
            ),

            // Hue Indicator.
            Positioned(
              left: hueDotPos.dx - 18,
              top: hueDotPos.dy - 18,
              child: IgnorePointer(
                child: _Indicator(
                  color: HSLColor.fromAHSL(1, _hue, 1, 0.5).toColor(),
                  isLarge: _isDraggingHue,
                ),
              ),
            ),

            // Sat/Light Indicator.
            Positioned(
              left: satLightDotPos.dx - 18,
              top: satLightDotPos.dy - 18,
              child: IgnorePointer(
                child: _Indicator(
                  color: _current,
                  isLarge: _isDraggingInner,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circular indicator used on the [ColorWheel].
class _Indicator extends StatelessWidget {
  final Color color;
  final bool isLarge;
  const _Indicator({required this.color, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: AppDuration.fast,
      scale: isLarge ? 1.25 : 1.0,
      curve: Curves.easeOutBack,
      child: Container(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for the outer hue ring.
class _HueRingPainter extends CustomPainter {
  final double ringWidth;
  _HueRingPainter({required this.ringWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF0000), // 0° Red
          Color(0xFFFFFF00), // 60° Yellow
          Color(0xFF00FF00), // 120° Green
          Color(0xFF00FFFF), // 180° Cyan
          Color(0xFF0000FF), // 240° Blue
          Color(0xFFFF00FF), // 300° Magenta
          Color(0xFFFF0000), // 360° Red
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius - ringWidth / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for the inner saturation/lightness circle.
class _SatLightPainter extends CustomPainter {
  final double hue;

  _SatLightPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    const int divisions = 32;
    final List<Offset> positions = [];
    final List<Color> colors = [];

    for (int j = 0; j <= divisions; j++) {
      final double l = 1.0 - j / divisions;
      final double y = size.height * j / divisions;
      for (int i = 0; i <= divisions; i++) {
        final double s = i / divisions;
        final double x = size.width * i / divisions;
        
        positions.add(Offset(x, y));
        colors.add(HSLColor.fromAHSL(1.0, hue, s, l).toColor());
      }
    }

    final List<int> indices = [];
    for (int j = 0; j < divisions; j++) {
      for (int i = 0; i < divisions; i++) {
        final int topLeft = j * (divisions + 1) + i;
        final int topRight = topLeft + 1;
        final int bottomLeft = (j + 1) * (divisions + 1) + i;
        final int bottomRight = bottomLeft + 1;

        indices.add(topLeft);
        indices.add(topRight);
        indices.add(bottomLeft);

        indices.add(topRight);
        indices.add(bottomRight);
        indices.add(bottomLeft);
      }
    }

    final vertices = Vertices(
      VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );

    canvas.drawVertices(vertices, BlendMode.srcOver, Paint()..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _SatLightPainter oldDelegate) =>
      oldDelegate.hue != hue;
}
