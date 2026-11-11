import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/drawn_object.dart';
import '../utils/bulge_arc.dart';
import '../utils/drawn_geometry.dart';

/// Геометрия нарисованных объектов в локальных координатах вьюера.
///
/// Рисуется внутри масштабируемого холста (линии масштабируются с чертежом,
/// толщина остаётся постоянной в экранных пикселях). Тексты (текст и подпись
/// размера) выводятся отдельным экранным слоем [DrawnTextsPainter].
class DrawnObjectsPainter extends CustomPainter {
  final List<DrawnObject> objects;

  /// Смещение мировых координат в локальные: (x - minX, maxY - y).
  final double minX, maxY;

  /// Масштаб «локальные единицы -> экранные пиксели».
  final double scale;

  /// Диагональ чертежа — запасной вариант для «прямой».
  final double extent;

  /// Видимая область в локальных координатах: «прямая» обрезается по ней,
  /// поэтому остаётся бесконечной на экране при любом зуме.
  final Rect? rayClip;

  /// Выбранный объект (рамка выделения) и его «живая» копия.
  final String? selectedId;
  final DrawnObject? edited;

  DrawnObjectsPainter({
    required this.objects,
    required this.minX,
    required this.maxY,
    required this.scale,
    required this.extent,
    this.rayClip,
    this.selectedId,
    this.edited,
  });

  double get _s => scale <= 0 ? 1.0 : scale;

  Offset _local(Offset world) => Offset(world.dx - minX, maxY - world.dy);

  @override
  void paint(Canvas canvas, Size size) {
    for (var object in objects) {
      if (edited != null && edited!.id == object.id) {
        object = edited!;
      }
      final color = Color(object.color);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = object.strokePx / _s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fill = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      switch (object.type) {
        case DrawnType.point:
          if (object.points.isEmpty) break;
          final p = _local(object.points.first);
          final arm = 4.0 / _s;
          canvas.drawLine(p - Offset(arm, 0), p + Offset(arm, 0), stroke);
          canvas.drawLine(p - Offset(0, arm), p + Offset(0, arm), stroke);
        case DrawnType.line:
          if (object.points.length < 2) break;
          canvas.drawLine(
              _local(object.points[0]), _local(object.points[1]), stroke);
        case DrawnType.ray:
          if (object.points.length < 2) break;
          final a = object.points[0];
          final b = object.points[1];
          final d = b - a;
          final len = d.distance;
          if (len < 1e-9) break;
          final u = d / len;
          // rayClip — в локальных координатах: переводим точку и направление.
          final aLocal = _local(a);
          final uLocal = Offset(u.dx, -u.dy);
          final clipped =
              rayClip == null ? null : clipLineToRect(aLocal, uLocal, rayClip!);
          if (clipped != null) {
            canvas.drawLine(clipped.start, clipped.end, stroke);
          } else {
            final big = extent * 20 + 1;
            canvas.drawLine(_local(a - u * big), _local(a + u * big), stroke);
          }
        case DrawnType.circle:
          if (object.points.length < 2) break;
          final c = object.points.first;
          final r = (object.points[1] - c).distance;
          if (r <= 0) break;
          canvas.drawCircle(_local(c), r, stroke);
        case DrawnType.rectangle:
          if (object.points.length < 4) break;
          final path = Path();
          final p0 = _local(object.points[0]);
          path.moveTo(p0.dx, p0.dy);
          for (var i = 1; i < 4; i++) {
            final p = _local(object.points[i]);
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, stroke);
        case DrawnType.polyline:
          _drawPolyline(canvas, object, stroke, closed: false);
        case DrawnType.cloud:
          _drawPolyline(canvas, object, stroke, closed: true);
        case DrawnType.text:
          // Текст рисуется экранным слоем.
          break;
        case DrawnType.dimension:
          _drawDimension(canvas, object, stroke, fill);
      }
      if (object.id == selectedId) {
        _drawSelection(canvas, object);
      }
    }
  }

  /// Рамка выделения выбранного объекта (для перемещения/поворота).
  void _drawSelection(Canvas canvas, DrawnObject object) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / _s;
    final dot = Paint()..color = Colors.cyanAccent;
    if (object.type == DrawnType.rectangle && object.points.length >= 4) {
      final pts = [for (final p in object.points) _local(p)];
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(path, paint);
      for (final p in pts) {
        canvas.drawCircle(p, 3.0 / _s, dot);
      }
      return;
    }
    // Прочие объекты — прямоугольник вокруг их габаритов.
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in object.points) {
      final q = _local(p);
      minX = math.min(minX, q.dx);
      minY = math.min(minY, q.dy);
      maxX = math.max(maxX, q.dx);
      maxY = math.max(maxY, q.dy);
    }
    if (minX.isFinite) {
      canvas.drawRect(
        Rect.fromLTRB(
            minX - 4 / _s, minY - 4 / _s, maxX + 4 / _s, maxY + 4 / _s),
        paint,
      );
    }
  }

  void _drawPolyline(
    Canvas canvas,
    DrawnObject object,
    Paint paint, {
    required bool closed,
  }) {
    if (object.points.isEmpty) return;
    final path = Path();
    final first = _local(object.points.first);
    path.moveTo(first.dx, first.dy);
    final n = object.points.length;
    final count = closed ? n : n - 1;
    for (var i = 0; i < count; i++) {
      final a = object.points[i];
      final b = object.points[(i + 1) % n];
      final bulge = i < object.bulges.length ? object.bulges[i] : 0.0;
      if (bulge.abs() < 1e-9) {
        final lb = _local(b);
        path.lineTo(lb.dx, lb.dy);
      } else {
        for (final point in bulgeArcPoints(a.dx, a.dy, b.dx, b.dy, bulge)) {
          final lp = _local(point);
          path.lineTo(lp.dx, lp.dy);
        }
      }
    }
    if (closed) path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDimension(
    Canvas canvas,
    DrawnObject object,
    Paint stroke,
    Paint fill,
  ) {
    if (object.points.length < 3) return;
    // Для старых объектов без высоты — читаемый экранный размер.
    final textHeight = object.height ?? (_s > 0 ? 12 / _s : 2.5);
    final layout = layoutDimension(
      object.points[0],
      object.points[1],
      object.points[2],
      textHeight: textHeight,
    );
    if (layout == null) return;

    canvas.drawLine(_local(object.points[0]), _local(layout.ext1End), stroke);
    canvas.drawLine(_local(object.points[1]), _local(layout.ext2End), stroke);
    final a = _local(layout.dimStart);
    final b = _local(layout.dimEnd);
    canvas.drawLine(a, b, stroke);

    final d = b - a;
    final len = d.distance;
    if (len > 1e-9) {
      final u = d / len;
      final arrowSize = 6.0 / _s;
      _arrow(canvas, a, u, arrowSize, fill);
      _arrow(canvas, b, -u, arrowSize, fill);
    }
  }

  void _arrow(
      Canvas canvas, Offset tip, Offset direction, double size, Paint fill) {
    final normal = Offset(-direction.dy, direction.dx);
    final base = tip + direction * size;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
          base.dx + normal.dx * size * 0.4, base.dy + normal.dy * size * 0.4)
      ..lineTo(
          base.dx - normal.dx * size * 0.4, base.dy - normal.dy * size * 0.4)
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant DrawnObjectsPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.minX != minX ||
        oldDelegate.maxY != maxY ||
        oldDelegate.scale != scale ||
        oldDelegate.extent != extent ||
        oldDelegate.rayClip != rayClip ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.edited != edited;
  }
}
