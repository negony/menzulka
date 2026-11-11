import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/snap_models.dart';

/// Цвет маркера (как жёлтый AutoSnap-маркер AutoCAD) и ореол под тёмный холст.
const Color snapMarkerColor = Color(0xFFFFE500);
const Color snapMarkerHalo = Color(0xFF212830);

/// Рисует глиф привязки в стиле AutoCAD 2024:
/// конечная точка — квадрат, узел — круг с крестом,
/// перпендикуляр — прямой угол с квадратом, ближайшая — «песочные часы».
void drawSnapGlyph(
  Canvas canvas,
  Offset center,
  SnapType type, {
  required double size,
  Color color = snapMarkerColor,
  Color halo = snapMarkerHalo,
  double stroke = 1.8,
}) {
  final half = size / 2;
  final haloPaint = Paint()
    ..color = halo
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke + 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void drawWithHalo(void Function(Canvas, Paint) draw) {
    draw(canvas, haloPaint);
    draw(canvas, paint);
  }

  switch (type) {
    case SnapType.vertex:
      // AutoCAD Endpoint — квадрат.
      drawWithHalo((c, p) => c.drawRect(
            Rect.fromCenter(center: center, width: size, height: size),
            p,
          ));
    case SnapType.point:
      // AutoCAD Node — круг с крестом внутри.
      final r = half;
      drawWithHalo((c, p) {
        c.drawCircle(center, r, p);
        c.drawLine(
          center - Offset(r * 0.55, 0),
          center + Offset(r * 0.55, 0),
          p,
        );
        c.drawLine(
          center - Offset(0, r * 0.55),
          center + Offset(0, r * 0.55),
          p,
        );
      });
    case SnapType.intersection:
      // AutoCAD Intersection — «X» (пересечение двух линий).
      drawWithHalo((c, p) {
        c.drawLine(
          center - Offset(half * 0.8, half * 0.8),
          center + Offset(half * 0.8, half * 0.8),
          p,
        );
        c.drawLine(
          center - Offset(-half * 0.8, half * 0.8),
          center + Offset(-half * 0.8, half * 0.8),
          p,
        );
      });
    case SnapType.perpendicular:
      // AutoCAD Perpendicular — прямой угол с квадратиком внутри.
      final arm = half;
      final sq = size * 0.32;
      drawWithHalo((c, p) {
        c.drawLine(center, center + Offset(arm, 0), p);
        c.drawLine(center, center - Offset(0, arm), p);
        c.drawRect(
          Rect.fromLTWH(
            center.dx + arm * 0.18,
            center.dy - arm * 0.18 - sq,
            sq,
            sq,
          ),
          p,
        );
      });
    case SnapType.tangent:
      // AutoCAD Tangent — окружность с касательной чертой сверху.
      final r = size * 0.2;
      final dashY = center.dy - r - size * 0.06;
      drawWithHalo((c, p) {
        c.drawCircle(center, r, p);
        c.drawLine(
          Offset(center.dx - size * 0.42, dashY),
          Offset(center.dx + size * 0.42, dashY),
          p,
        );
      });
    case SnapType.nearest:
      // AutoCAD Nearest — «песочные часы» с вершиной в точке привязки.
      final w = half;
      final h = half;
      drawWithHalo((c, p) {
        final path = Path()
          ..moveTo(center.dx - w, center.dy - h)
          ..lineTo(center.dx + w, center.dy - h)
          ..lineTo(center.dx - w, center.dy + h)
          ..lineTo(center.dx + w, center.dy + h)
          ..close();
        c.drawPath(path, p);
      });
  }
}

/// Маленький глиф для списка настроек привязок.
class SnapGlyph extends StatelessWidget {
  final SnapType type;
  final double size;
  final Color color;

  const SnapGlyph({
    super.key,
    required this.type,
    this.size = 22,
    this.color = const Color(0xFF37474F),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SnapGlyphPainter(type, size, color)),
    );
  }
}

class _SnapGlyphPainter extends CustomPainter {
  final SnapType type;
  final double size;
  final Color color;

  _SnapGlyphPainter(this.type, this.size, this.color);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    drawSnapGlyph(
      canvas,
      Offset(canvasSize.width / 2, canvasSize.height / 2),
      type,
      size: math.min(canvasSize.width, canvasSize.height) * 0.55,
      color: color,
      halo: Colors.transparent,
      stroke: 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SnapGlyphPainter old) =>
      old.type != type || old.size != size || old.color != color;
}
