import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dxf_models.dart';

/// Ищет высоту (Z/elevation) объекта чертежа, к которому относится точка.
///
/// Нужна для режима «Координаты»: H берётся из самого объекта — у линии это
/// отметка начальной точки (группа 30), у полилинии — отметка (38), у
/// окружности/дуги/эллипса — отметка центра, у точки/текста/вставки — отметка
/// точки вставки. Возвращает null, если рядом с точкой объектов нет.
double? elevationAtPoint(
  DxfDocument document,
  Offset world, {
  Set<String> hiddenLayers = const {},
}) {
  final diag = math.sqrt(
    math.pow(document.maxX - document.minX, 2) +
        math.pow(document.maxY - document.minY, 2),
  );
  final tolerance = diag.isFinite && diag > 0 ? diag * 0.002 : 1.0;

  double best = double.infinity;
  double? bestElevation;

  void consider(DxfEntity e, double? distance) {
    if (distance == null) return;
    if (hiddenLayers.contains(e.layer)) return;
    if (distance <= tolerance && distance < best) {
      best = distance;
      bestElevation = e.elevation;
    }
  }

  for (final e in document.entities) {
    consider(e, _distanceToEntity(e, world));
  }
  return bestElevation;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared <= 1e-18) return (p - a).distance;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double? _distanceToEntity(DxfEntity e, Offset p) {
  // Общая «вершинная» оценка для полилиний и ломаных.
  double? polylineDistance(List<DxfVertex> vertices, bool closed) {
    if (vertices.isEmpty) return null;
    if (vertices.length == 1) {
      return (p - Offset(vertices.first.x, vertices.first.y)).distance;
    }
    var best = double.infinity;
    final n = vertices.length;
    final segments = closed ? n : n - 1;
    for (var i = 0; i < segments; i++) {
      final a = Offset(vertices[i].x, vertices[i].y);
      final b = Offset(vertices[(i + 1) % n].x, vertices[(i + 1) % n].y);
      best = math.min(best, _distanceToSegment(p, a, b));
    }
    return best;
  }

  switch (e) {
    case DxfLine l:
      return _distanceToSegment(p, Offset(l.x1, l.y1), Offset(l.x2, l.y2));
    case DxfLwPolyline l:
      return polylineDistance(l.vertices, l.isClosed);
    case DxfPolyline l:
      return polylineDistance(l.vertices, l.isClosed);
    case DxfCircle c:
      return ((p - Offset(c.cx, c.cy)).distance - c.radius).abs();
    case DxfArc a:
      // Угловой диапазон не учитываем: точка привязки лежит на дуге.
      return ((p - Offset(a.cx, a.cy)).distance - a.radius).abs();
    case DxfEllipse el:
      final nx = -el.majorY * el.ratio;
      final ny = el.majorX * el.ratio;
      var best = double.infinity;
      const segs = 48;
      for (var i = 0; i <= segs; i++) {
        final t = el.startParam + (el.endParam - el.startParam) * i / segs;
        final x = el.cx + el.majorX * math.cos(t) + nx * math.sin(t);
        final y = el.cy + el.majorY * math.cos(t) + ny * math.sin(t);
        best = math.min(best, (p - Offset(x, y)).distance);
      }
      return best;
    case DxfPoint pt:
      return (p - Offset(pt.x, pt.y)).distance;
    case DxfText t:
      return (p - Offset(t.x, t.y)).distance;
    case DxfInsert i:
      return (p - Offset(i.x, i.y)).distance;
    case DxfSolid s:
      return polylineDistance(s.points, true);
    case DxfSpline s:
      return polylineDistance(s.points, s.isClosed);
    case DxfRay r:
      final base = Offset(r.x, r.y);
      final dir = Offset(r.dx, r.dy);
      final len = dir.distance;
      if (len <= 1e-12) return (p - base).distance;
      final u = dir / len;
      var t = (p - base).dx * u.dx + (p - base).dy * u.dy;
      if (!r.isInfinite) t = math.max(0, t);
      return (p - (base + u * t)).distance;
    default:
      return null;
  }
}
