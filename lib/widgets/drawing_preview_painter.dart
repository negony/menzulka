import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/drawn_object.dart';
import '../utils/bulge_arc.dart';
import '../utils/drawn_geometry.dart';

/// Живое превью незавершённого рисования: «резиновые» линии полилинии/
/// отрезка/прямой, окружность по радиусу, путь облака, выносные линии размера.
class DrawingPreviewPainter extends CustomPainter {
  final DrawnType tool;

  /// Зафиксированные точки (мировые координаты).
  final List<Offset> picks;

  /// Текущая точка пальца/прицеливания (мировая), если есть.
  final Offset? aim;

  /// Путь свободного рисования облака (мировые координаты).
  final List<Offset> cloudPath;

  final double minX, maxY;
  final double scale;
  final Color color;
  final double strokePx;

  /// Видимая область в локальных координатах (для «прямой»).
  final Rect? rayClip;

  DrawingPreviewPainter({
    required this.tool,
    required this.picks,
    required this.aim,
    required this.cloudPath,
    required this.minX,
    required this.maxY,
    required this.scale,
    required this.color,
    required this.strokePx,
    this.rayClip,
  });

  double get _s => scale <= 0 ? 1.0 : scale;

  Offset _local(Offset world) => Offset(world.dx - minX, maxY - world.dy);

  @override
  void paint(Canvas canvas, Size size) {
    if (picks.isEmpty && cloudPath.isEmpty && aim == null) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokePx / _s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dash = 6.0 / _s;
    final gap = 4.0 / _s;
    final picksLocal = picks.map(_local).toList();
    final aimLocal = aim == null ? null : _local(aim!);

    switch (tool) {
      case DrawnType.polyline:
        _drawPolyline(canvas, picksLocal, false, paint);
        if (aimLocal != null && picksLocal.isNotEmpty) {
          _dashed(canvas, picksLocal.last, aimLocal, paint, dash, gap);
        }
      case DrawnType.line:
        if (picksLocal.isNotEmpty && aimLocal != null) {
          _dashed(canvas, picksLocal.first, aimLocal, paint, dash, gap);
        }
      case DrawnType.ray:
        if (picksLocal.isNotEmpty && aimLocal != null) {
          final d = aimLocal - picksLocal.first;
          final len = d.distance;
          if (len > 1e-9) {
            final u = d / len;
            final clipped = rayClip == null
                ? null
                : clipLineToRect(picksLocal.first, u, rayClip!);
            if (clipped != null) {
              canvas.drawLine(clipped.start, clipped.end, paint);
            } else {
              // Сплошная линия — один вызов отрисовки: пунктир на такой длине
              // давал сотни тысяч штрихов и вешал приложение (ANR).
              const big = 1e6;
              canvas.drawLine(picksLocal.first - u * big,
                  picksLocal.first + u * big, paint);
            }
          }
        }
      case DrawnType.circle:
        if (picksLocal.isNotEmpty && aimLocal != null) {
          final r = (aimLocal - picksLocal.first).distance;
          if (r > 1e-9) {
            _dashedCircle(canvas, picksLocal.first, r, paint);
            _dashed(canvas, picksLocal.first, aimLocal, paint, dash, gap);
          }
        }
      case DrawnType.cloud:
        // Превью облака — волнистый контур (как у готового объекта).
        if (cloudPath.isNotEmpty) {
          final cloud = buildCloudFromPolygon(cloudPath);
          _drawBulgedPolyline(
            canvas,
            cloud.vertices.map(_local).toList(),
            cloud.bulges,
            true,
            paint,
          );
          if (aimLocal != null) {
            _dashed(canvas, _local(cloud.vertices.last), aimLocal, paint, dash,
                gap);
          }
        } else if (picksLocal.isNotEmpty) {
          _drawPolyline(canvas, picksLocal, false, paint);
          if (aimLocal != null) {
            _dashed(canvas, picksLocal.last, aimLocal, paint, dash, gap);
          }
        }
      case DrawnType.rectangle:
        if (picksLocal.isNotEmpty && aimLocal != null) {
          final rect = rectangleCorners(picks[0], aim!);
          _drawPolyline(canvas, rect.map(_local).toList(), true, paint);
        }
      case DrawnType.dimension:
        if (picksLocal.length == 2) {
          final p3 = aim ?? defaultDimensionShelf(picks[0], picks[1], 40 / _s);
          final layout = layoutDimension(
            picks[0],
            picks[1],
            p3,
            textHeight: 12 / _s,
          );
          if (layout != null) {
            _dashed(canvas, _local(picks[0]), _local(layout.ext1End), paint,
                dash, gap);
            _dashed(canvas, _local(picks[1]), _local(layout.ext2End), paint,
                dash, gap);
            _dashed(canvas, _local(layout.dimStart), _local(layout.dimEnd),
                paint, dash, gap);
          }
        } else if (picksLocal.length == 1 && aimLocal != null) {
          _dashed(canvas, picksLocal.first, aimLocal, paint, dash, gap);
        }
      case DrawnType.point:
      case DrawnType.text:
        break;
    }

    // Маркер текущей точки.
    if (aimLocal != null) {
      canvas.drawCircle(
        aimLocal,
        4 / _s,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / _s,
      );
    }
  }

  void _drawPolyline(
      Canvas canvas, List<Offset> pts, bool closed, Paint paint) {
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    if (closed) path.close();
    canvas.drawPath(path, paint);
  }

  /// Полилиния с дугами (bulge) — для волнистого облака.
  void _drawBulgedPolyline(
    Canvas canvas,
    List<Offset> pts,
    List<double> bulges,
    bool closed,
    Paint paint,
  ) {
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    final n = closed ? pts.length : pts.length - 1;
    for (var i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final bulge = i < bulges.length ? bulges[i] : 0.0;
      if (bulge.abs() < 1e-9) {
        path.lineTo(b.dx, b.dy);
        continue;
      }
      for (final point in bulgeArcPoints(a.dx, a.dy, b.dx, b.dy, bulge)) {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (closed) path.close();
    canvas.drawPath(path, paint);
  }

  void _dashed(
      Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    // Страховка от «бесконечных» линий: не больше 2000 штрихов за кадр.
    var count = 0;
    while (t < total && count < 2000) {
      final end = (t + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
      count++;
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const segments = 72;
    for (var i = 0; i < segments; i += 2) {
      final a1 = i / segments * 2 * math.pi;
      final a2 = (i + 1) / segments * 2 * math.pi;
      canvas.drawLine(
        Offset(c.dx + r * math.cos(a1), c.dy + r * math.sin(a1)),
        Offset(c.dx + r * math.cos(a2), c.dy + r * math.sin(a2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPreviewPainter oldDelegate) {
    return oldDelegate.tool != tool ||
        oldDelegate.picks != picks ||
        oldDelegate.aim != aim ||
        oldDelegate.cloudPath != cloudPath ||
        oldDelegate.minX != minX ||
        oldDelegate.maxY != maxY ||
        oldDelegate.scale != scale ||
        oldDelegate.color != color ||
        oldDelegate.strokePx != strokePx;
  }
}
