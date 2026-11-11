import 'dart:math' as math;
import 'dart:ui';

import '../models/drawn_object.dart';
import '../models/snap_models.dart';

/// Привязка к нарисованным пользователем объектам: вершины/точки и
/// ближайшая точка на отрезках, полилиниях, прямоугольниках, облаке,
/// круге и «прямой».
class DrawnSnapIndex {
  final List<_Dv> _vertices = [];
  final List<_Dv> _points = [];
  final List<_Ds> _segments = [];
  final List<_Dc> _circles = [];
  final List<_Dl> _lines = [];

  DrawnSnapIndex(List<DrawnObject> objects) {
    for (final o in objects) {
      switch (o.type) {
        case DrawnType.point:
          if (o.points.isNotEmpty) _points.add(_Dv(o.points.first));
        case DrawnType.line:
          if (o.points.length >= 2) {
            _vertices.add(_Dv(o.points[0]));
            _vertices.add(_Dv(o.points[1]));
            _segments.add(_Ds(o.points[0], o.points[1]));
          }
        case DrawnType.ray:
          if (o.points.length >= 2) {
            final d = o.points[1] - o.points[0];
            final len = d.distance;
            if (len > 1e-9) {
              _vertices.add(_Dv(o.points[0]));
              _lines.add(_Dl(o.points[0], d / len));
            }
          }
        case DrawnType.polyline:
          _addPolyline(o.points, closed: false);
        case DrawnType.rectangle:
          if (o.points.length >= 4) {
            for (final p in o.points) {
              _vertices.add(_Dv(p));
            }
            for (var i = 0; i < 4; i++) {
              _segments.add(_Ds(o.points[i], o.points[(i + 1) % 4]));
            }
          }
        case DrawnType.cloud:
          if (o.points.length >= 2) {
            for (final p in o.points) {
              _vertices.add(_Dv(p));
            }
            final n = o.points.length;
            for (var i = 0; i < n; i++) {
              _segments.add(_Ds(o.points[i], o.points[(i + 1) % n]));
            }
          }
        case DrawnType.circle:
          if (o.points.length >= 2) {
            final r = (o.points[1] - o.points.first).distance;
            if (r > 0) _circles.add(_Dc(o.points.first, r));
          }
        case DrawnType.dimension:
          if (o.points.length >= 2) {
            _vertices.add(_Dv(o.points[0]));
            _vertices.add(_Dv(o.points[1]));
          }
        case DrawnType.text:
          // Позиция текста — как вершина (привязка «Конечная точка»).
          if (o.points.isNotEmpty) _vertices.add(_Dv(o.points.first));
      }
    }
  }

  void _addPolyline(List<Offset> points, {required bool closed}) {
    final n = points.length;
    for (final p in points) {
      _vertices.add(_Dv(p));
    }
    final count = closed ? n : n - 1;
    for (var i = 0; i < count; i++) {
      _segments.add(_Ds(points[i], points[(i + 1) % n]));
    }
  }

  SnapResult? query(
    Offset world, {
    required double tolerance,
    SnapSettings? settings,
    Offset? from,
  }) {
    final snap = settings ?? SnapSettings();
    if (!snap.enabled) return null;
    final tol = tolerance <= 0 ? 0.0 : tolerance;
    final tol2 = tol * tol;
    Offset? best;
    SnapType? type;
    double bestD2 = double.infinity;

    void consider(Offset p, SnapType t) {
      final dx = p.dx - world.dx;
      final dy = p.dy - world.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= tol2 && d2 < bestD2) {
        best = p;
        bestD2 = d2;
        type = t;
      }
    }

    if (snap.vertex) {
      for (final v in _vertices) {
        consider(v.p, SnapType.vertex);
      }
    }
    if (snap.point) {
      for (final p in _points) {
        consider(p.p, SnapType.point);
      }
    }
    if (best != null) {
      return SnapResult(
        point: best!,
        type: type!,
        distance: math.sqrt(bestD2),
        source: SnapSource.drawn,
      );
    }

    // Пересечения нарисованных фигур.
    if (snap.intersection) {
      final segs = <_Ds>[];
      for (final s in _segments) {
        if ((_closestOnSegment(world, s.a, s.b) - world).distance <=
            tol + 1e-9) {
          segs.add(s);
        }
      }
      final circles = <_Dc>[];
      for (final c in _circles) {
        if (((world - c.c).distance - c.r).abs() <= tol + 1e-9) {
          circles.add(c);
        }
      }
      for (var i = 0; i < segs.length; i++) {
        for (var j = i + 1; j < segs.length; j++) {
          final p = _segIntersection(segs[i], segs[j]);
          if (p != null) consider(p, SnapType.intersection);
        }
        for (final c in circles) {
          for (final p in _segCircleIntersections(segs[i], c)) {
            consider(p, SnapType.intersection);
          }
        }
      }
      for (var i = 0; i < circles.length; i++) {
        for (var j = i + 1; j < circles.length; j++) {
          for (final p in _circleIntersections(circles[i], circles[j])) {
            consider(p, SnapType.intersection);
          }
        }
      }
      // Прямые (бесконечные) — с отрезками, кругами и между собой.
      for (final l in _lines) {
        for (final s in segs) {
          final p = _lineSegIntersection(l, s);
          if (p != null) consider(p, SnapType.intersection);
        }
        for (final c in circles) {
          for (final p in _lineCircleIntersections(l, c)) {
            consider(p, SnapType.intersection);
          }
        }
      }
      for (var i = 0; i < _lines.length; i++) {
        for (var j = i + 1; j < _lines.length; j++) {
          final p = _lineLineIntersection(_lines[i], _lines[j]);
          if (p != null) consider(p, SnapType.intersection);
        }
      }
      if (best != null) {
        return SnapResult(
            point: best!,
            type: type!,
            distance: math.sqrt(bestD2),
            source: SnapSource.drawn);
      }
    }

    // Перпендикуляр от предыдущей точки (для нарисованных отрезков и прямых).
    if (snap.perpendicular && from != null) {
      for (final s in _segments) {
        final foot = _perpOnSegment(from, s.a, s.b);
        if (foot != null) consider(foot, SnapType.perpendicular);
      }
      for (final l in _lines) {
        final t = (from - l.p).dx * l.u.dx + (from - l.p).dy * l.u.dy;
        consider(l.p + l.u * t, SnapType.perpendicular);
      }
      if (best != null) {
        return SnapResult(
            point: best!,
            type: type!,
            distance: math.sqrt(bestD2),
            source: SnapSource.drawn);
      }
    }

    if (snap.nearest) {
      for (final s in _segments) {
        consider(_closestOnSegment(world, s.a, s.b), SnapType.nearest);
      }
      for (final c in _circles) {
        final d = world - c.c;
        final len = d.distance;
        if (len > 1e-9) {
          consider(c.c + d / len * c.r, SnapType.nearest);
        }
      }
      for (final l in _lines) {
        final t = (world - l.p).dx * l.u.dx + (world - l.p).dy * l.u.dy;
        consider(l.p + l.u * t, SnapType.nearest);
      }
    }
    if (best == null) return null;
    return SnapResult(
      point: best!,
      type: type!,
      distance: math.sqrt(bestD2),
      source: SnapSource.drawn,
    );
  }

  Offset _closestOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 <= 1e-18) return a;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  /// Основание перпендикуляра из [from] на отрезок (в пределах отрезка).
  Offset? _perpOnSegment(Offset from, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 <= 1e-18) return null;
    final t = ((from.dx - a.dx) * ab.dx + (from.dy - a.dy) * ab.dy) / len2;
    if (t < 0 || t > 1) return null;
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  /// Пересечение бесконечной прямой с отрезком.
  Offset? _lineSegIntersection(_Dl l, _Ds s) {
    final d = s.b - s.a;
    final den = l.u.dx * d.dy - l.u.dy * d.dx;
    if (den.abs() < 1e-12) return null;
    final q = s.a - l.p;
    final t = (q.dx * d.dy - q.dy * d.dx) / den;
    final u = (q.dx * l.u.dy - q.dy * l.u.dx) / den;
    if (u < -1e-9 || u > 1 + 1e-9) return null;
    return l.p + l.u * t;
  }

  /// Пересечения бесконечной прямой с кругом.
  List<Offset> _lineCircleIntersections(_Dl l, _Dc c) {
    final f = l.p - c.c;
    final b2 = 2 * (f.dx * l.u.dx + f.dy * l.u.dy);
    final c2 = f.dx * f.dx + f.dy * f.dy - c.r * c.r;
    final disc = b2 * b2 - 4 * c2;
    if (disc < 0) return const [];
    final sq = math.sqrt(disc);
    final out = <Offset>[];
    for (final t in [(-b2 - sq) / 2, (-b2 + sq) / 2]) {
      final p = l.p + l.u * t;
      if (out.every((q) => (q - p).distance > 1e-9)) out.add(p);
    }
    return out;
  }

  /// Пересечение двух бесконечных прямых.
  Offset? _lineLineIntersection(_Dl a, _Dl b) {
    final den = a.u.dx * b.u.dy - a.u.dy * b.u.dx;
    if (den.abs() < 1e-12) return null;
    final q = b.p - a.p;
    final t = (q.dx * b.u.dy - q.dy * b.u.dx) / den;
    return a.p + a.u * t;
  }

  Offset? _segIntersection(_Ds s1, _Ds s2) {
    final d1 = s1.b - s1.a;
    final d2 = s2.b - s2.a;
    final den = d1.dx * d2.dy - d1.dy * d2.dx;
    if (den.abs() < 1e-12) return null;
    final t = ((s2.a.dx - s1.a.dx) * d2.dy - (s2.a.dy - s1.a.dy) * d2.dx) / den;
    final u = ((s2.a.dx - s1.a.dx) * d1.dy - (s2.a.dy - s1.a.dy) * d1.dx) / den;
    if (t < -1e-9 || t > 1 + 1e-9 || u < -1e-9 || u > 1 + 1e-9) return null;
    return Offset(s1.a.dx + d1.dx * t, s1.a.dy + d1.dy * t);
  }

  List<Offset> _segCircleIntersections(_Ds s, _Dc c) {
    final d = s.b - s.a;
    final a2 = d.dx * d.dx + d.dy * d.dy;
    if (a2 < 1e-18) return const [];
    final f = s.a - c.c;
    final b2 = 2 * (f.dx * d.dx + f.dy * d.dy);
    final c2 = f.dx * f.dx + f.dy * f.dy - c.r * c.r;
    final disc = b2 * b2 - 4 * a2 * c2;
    if (disc < 0) return const [];
    final sq = math.sqrt(disc);
    final out = <Offset>[];
    for (final t in [(-b2 - sq) / (2 * a2), (-b2 + sq) / (2 * a2)]) {
      if (t < -1e-9 || t > 1 + 1e-9) continue;
      out.add(Offset(s.a.dx + d.dx * t, s.a.dy + d.dy * t));
    }
    return out;
  }

  List<Offset> _circleIntersections(_Dc c1, _Dc c2) {
    final d = c2.c - c1.c;
    final dist = d.distance;
    if (dist < 1e-9) return const [];
    if (dist > c1.r + c2.r + 1e-9) return const [];
    if (dist < (c1.r - c2.r).abs() - 1e-9) return const [];
    final a = (c1.r * c1.r - c2.r * c2.r + dist * dist) / (2 * dist);
    final h2 = c1.r * c1.r - a * a;
    if (h2 < 0) return const [];
    final h = math.sqrt(h2);
    final ux = d.dx / dist;
    final uy = d.dy / dist;
    final mid = Offset(c1.c.dx + ux * a, c1.c.dy + uy * a);
    return [
      Offset(mid.dx - uy * h, mid.dy + ux * h),
      Offset(mid.dx + uy * h, mid.dy - ux * h),
    ];
  }
}

class _Dv {
  final Offset p;
  const _Dv(this.p);
}

class _Ds {
  final Offset a, b;
  const _Ds(this.a, this.b);
}

class _Dc {
  final Offset c;
  final double r;
  const _Dc(this.c, this.r);
}

class _Dl {
  final Offset p, u;
  const _Dl(this.p, this.u);
}
