import 'dart:math' as math;
import 'dart:ui';

import '../models/dxf_models.dart';
import '../models/drawn_object.dart';
import '../models/snap_models.dart';
import '../utils/dxf_affine.dart';

/// Индекс примитивов чертежа для объектных привязок (мировые координаты DXF).
///
/// Строится один раз на документ; запросы — по курсору с допуском в мировых
/// единицах (экранные пиксели делятся на масштаб во вьюере).
class SnapEngine {
  SnapEngine(this.document, {List<DrawnObject> drawnObjects = const []})
      : _drawnObjects = drawnObjects {
    _build();
    _addDrawnObjects();
  }

  final DxfDocument document;
  final List<DrawnObject> _drawnObjects;

  final List<_V> _vertices = [];
  final List<_V> _points = [];
  final List<_Seg> _segments = [];
  final List<_Arc> _arcs = [];
  final List<_Ellipse> _ellipses = [];
  final List<_Line> _infiniteLines = [];

  static const double _eps = 1e-9;
  static const double _twoPi = math.pi * 2;

  // ---------- построение индекса ----------

  void _build() {
    for (final e in document.entities) {
      _addEntity(e, DxfAffine.identity, e.layer, 0);
    }
  }

  void _addEntity(DxfEntity e, DxfAffine xf, String layer, int depth) {
    if (e is DxfInsert) {
      final p = xf.apply(e.x, e.y);
      _points.add(_V(Offset(p.x, p.y), layer));
      final block = document.blocks[e.blockName];
      if (block == null || depth > 8) return;
      final child = xf.mul(insertAffine(e, block));
      for (final be in block.entities) {
        _addEntity(be, child, layer, depth + 1);
      }
      return;
    }

    final identity = xf.isIdentity;
    final similarity = xf.isSimilarity;
    final scale = xf.uniformScale;

    Offset tr(double x, double y) {
      final r = xf.apply(x, y);
      return Offset(r.x, r.y);
    }

    switch (e) {
      case DxfLine l:
        final a = tr(l.x1, l.y1);
        final b = tr(l.x2, l.y2);
        _vertices
          ..add(_V(a, layer))
          ..add(_V(b, layer));
        _addSeg(a, b, layer, perp: true);
      case DxfLwPolyline p:
        _addPolyline(p.vertices, p.isClosed, layer, xf, tr);
      case DxfPolyline p:
        _addPolyline(p.vertices, p.isClosed, layer, xf, tr);
      case DxfArc arc:
        var start = arc.startAngle * math.pi / 180;
        var end = arc.endAngle * math.pi / 180;
        if (end <= start) end += _twoPi;
        final sweep = end - start;
        final c = tr(arc.cx, arc.cy);
        if (identity) {
          _addArc(c, arc.radius, start, sweep, layer);
          _vertices
            ..add(_V(_pt(c, arc.radius, start), layer))
            ..add(_V(_pt(c, arc.radius, start + sweep), layer));
        } else if (similarity) {
          final r = arc.radius * scale;
          final st = start + xf.rotationDeg * math.pi / 180;
          _addArc(c, r, st, sweep, layer);
          _vertices
            ..add(_V(_pt(c, r, st), layer))
            ..add(_V(_pt(c, r, st + sweep), layer));
        } else {
          final pts = <Offset>[];
          const segs = 32;
          for (var i = 0; i <= segs; i++) {
            final a = start + sweep * i / segs;
            pts.add(tr(
              arc.cx + arc.radius * math.cos(a),
              arc.cy + arc.radius * math.sin(a),
            ));
          }
          _addSampled(pts, layer);
          _vertices
            ..add(_V(pts.first, layer))
            ..add(_V(pts.last, layer));
        }
      case DxfCircle c:
        final cc = tr(c.cx, c.cy);
        if (identity) {
          _addArc(cc, c.radius, 0, _twoPi, layer);
        } else if (similarity) {
          _addArc(cc, c.radius * scale, 0, _twoPi, layer);
        } else {
          final pts = <Offset>[];
          const segs = 32;
          for (var i = 0; i <= segs; i++) {
            final a = _twoPi * i / segs;
            pts.add(tr(
              c.cx + c.radius * math.cos(a),
              c.cy + c.radius * math.sin(a),
            ));
          }
          _addSampled(pts, layer);
        }
      case DxfEllipse el:
        var start = el.startParam;
        var end = el.endParam;
        final full = (end - start).abs() >= _twoPi - 1e-6;
        if (full) {
          start = 0;
          end = _twoPi;
        }
        final nx = -el.majorY * el.ratio;
        final ny = el.majorX * el.ratio;
        final pts = <Offset>[];
        const segs = 72;
        for (var i = 0; i <= segs; i++) {
          final t = start + (end - start) * i / segs;
          final x = el.cx + el.majorX * math.cos(t) + nx * math.sin(t);
          final y = el.cy + el.majorY * math.cos(t) + ny * math.sin(t);
          pts.add(tr(x, y));
        }
        _addSampled(pts, layer);
        if (!full) {
          _vertices
            ..add(_V(pts.first, layer))
            ..add(_V(pts.last, layer));
        }
        // Точная эллиптическая геометрия — для привязки «касательная».
        if (identity || similarity) {
          final cc = tr(el.cx, el.cy);
          final m = Offset(
            xf.a * el.majorX + xf.b * el.majorY,
            xf.d * el.majorX + xf.e * el.majorY,
          );
          final minor = Offset(-m.dy * el.ratio, m.dx * el.ratio);
          var rect = Rect.fromPoints(pts.first, pts.first);
          for (final p in pts) {
            rect = rect.expandToInclude(Rect.fromPoints(p, p));
          }
          _ellipses.add(_Ellipse(
            c: cc,
            major: m,
            minor: minor,
            start: start,
            end: end,
            layer: layer,
            box: rect.inflate(1e-6),
          ));
        }
      case DxfPoint p:
        final w = tr(p.x, p.y);
        _points.add(_V(w, layer));
      case DxfSpline s:
        final verts = s.points.map((v) => tr(v.x, v.y)).toList();
        for (final v in verts) {
          _vertices.add(_V(v, layer));
        }
        final n = verts.length;
        final count = s.isClosed ? n : n - 1;
        for (var i = 0; i < count; i++) {
          _addSeg(verts[i], verts[(i + 1) % n], layer, perp: true);
        }
      case DxfText t:
        // Точка вставки текста — как у блока (привязка «Конечная точка»).
        final w = tr(t.x, t.y);
        _vertices.add(_V(w, layer));
      case DxfSolid solid:
        final pts = [for (final p in solid.points) tr(p.x, p.y)];
        for (final p in pts) {
          _vertices.add(_V(p, layer));
        }
        // Контур: у треугольника 4-я точка совпадает с 3-й.
        var n = pts.length;
        if (n == 4 && _same(pts[2], pts[3])) n = 3;
        if (n >= 2) {
          for (var i = 0; i < n; i++) {
            _addSeg(pts[i], pts[(i + 1) % n], layer, perp: true);
          }
        }
      case DxfRay r:
        final base = tr(r.x, r.y);
        _vertices.add(_V(base, layer));
        // Направление без переноса: apply(base + dir) - apply(base).
        final tip = tr(r.x + r.dx, r.y + r.dy);
        final dir = tip - base;
        final len = dir.distance;
        if (len > _eps) {
          _infiniteLines.add(_Line(base, dir / len, r.isInfinite, layer));
        }
      default:
        break;
    }
  }

  void _addPolyline(
    List<DxfVertex> verts,
    bool closed,
    String layer,
    DxfAffine xf,
    Offset Function(double, double) tr, {
    SnapSource source = SnapSource.dxf,
  }) {
    if (verts.isEmpty) return;
    final identity = xf.isIdentity;
    final similarity = xf.isSimilarity;
    final pts = <Offset>[];
    for (final v in verts) {
      final p = xf.apply(v.x, v.y);
      pts.add(Offset(p.x, p.y));
    }
    for (final p in pts) {
      _vertices.add(_V(p, layer, source));
    }
    final n = verts.length;
    final count = closed ? n : n - 1;
    for (var i = 0; i < count; i++) {
      final a = verts[i];
      final b = verts[(i + 1) % n];
      final pa = pts[i];
      final pb = pts[(i + 1) % n];
      if (a.bulge.abs() < 1e-9) {
        _addSeg(pa, pb, layer, perp: true, source: source);
        continue;
      }
      final geom = _bulgeGeometry(a.x, a.y, b.x, b.y, a.bulge);
      if (geom == null) {
        _addSeg(pa, pb, layer, perp: true, source: source);
        continue;
      }
      if (identity) {
        _addArc(geom.c, geom.r, geom.start, geom.sweep, layer, source);
      } else if (similarity) {
        final c = tr(geom.c.dx, geom.c.dy);
        final r = geom.r * xf.uniformScale;
        final st = geom.start + xf.rotationDeg * math.pi / 180;
        _addArc(c, r, st, geom.sweep, layer, source);
      } else {
        final samples = <Offset>[];
        const segs = 24;
        for (var k = 0; k <= segs; k++) {
          final ang = geom.start + geom.sweep * k / segs;
          samples.add(tr(
            geom.c.dx + geom.r * math.cos(ang),
            geom.c.dy + geom.r * math.sin(ang),
          ));
        }
        _addSampled(samples, layer, source);
      }
    }
  }

  void _addArc(Offset c, double r, double start, double sweep, String layer,
      [SnapSource source = SnapSource.dxf]) {
    if (r <= _eps || sweep.abs() < 1e-9) return;
    _arcs.add(_Arc(
      c: c,
      r: r,
      start: start,
      sweep: sweep,
      layer: layer,
      box: Rect.fromCircle(center: c, radius: r + 1e-6),
      source: source,
    ));
  }

  void _addSeg(Offset a, Offset b, String layer,
      {required bool perp, SnapSource source = SnapSource.dxf}) {
    if ((b - a).distance <= _eps) return;
    _segments.add(_Seg(
      a: a,
      b: b,
      layer: layer,
      perp: perp,
      box: Rect.fromPoints(a, b).inflate(1e-6),
      source: source,
    ));
  }

  void _addSampled(List<Offset> pts, String layer,
      [SnapSource source = SnapSource.dxf]) {
    for (var i = 0; i + 1 < pts.length; i++) {
      _addSeg(pts[i], pts[i + 1], layer, perp: false, source: source);
    }
  }

  /// Добавляет в индекс нарисованные пользователем объекты (источник drawn).
  /// Благодаря единому индексу работают и «смешанные» пересечения:
  /// нарисованная прямая × примитив чертежа и наоборот.
  void _addDrawnObjects() {
    const src = SnapSource.drawn;
    for (final o in _drawnObjects) {
      switch (o.type) {
        case DrawnType.point:
          if (o.points.isNotEmpty) {
            _points.add(_V(o.points.first, o.layer, src));
          }
        case DrawnType.line:
          if (o.points.length >= 2) {
            _vertices.add(_V(o.points[0], o.layer, src));
            _vertices.add(_V(o.points[1], o.layer, src));
            _addSeg(o.points[0], o.points[1], o.layer, perp: true, source: src);
          }
        case DrawnType.ray:
          if (o.points.length >= 2) {
            final d = o.points[1] - o.points[0];
            final len = d.distance;
            if (len > _eps) {
              _vertices.add(_V(o.points[0], o.layer, src));
              _infiniteLines
                  .add(_Line(o.points[0], d / len, true, o.layer, src));
            }
          }
        case DrawnType.polyline:
          _addDrawnPolyline(o.points, false, o.layer, src);
        case DrawnType.rectangle:
          if (o.points.length >= 4) {
            for (var i = 0; i < 4; i++) {
              _vertices.add(_V(o.points[i], o.layer, src));
              _addSeg(o.points[i], o.points[(i + 1) % 4], o.layer,
                  perp: true, source: src);
            }
          }
        case DrawnType.cloud:
          if (o.points.length >= 2) {
            _addDrawnPolyline(o.points, true, o.layer, src);
          }
        case DrawnType.circle:
          if (o.points.length >= 2) {
            final r = (o.points[1] - o.points.first).distance;
            if (r > 0) _addArc(o.points.first, r, 0, _twoPi, o.layer, src);
          }
        case DrawnType.dimension:
          if (o.points.length >= 2) {
            _vertices.add(_V(o.points[0], o.layer, src));
            _vertices.add(_V(o.points[1], o.layer, src));
          }
        case DrawnType.text:
          if (o.points.isNotEmpty) {
            _vertices.add(_V(o.points.first, o.layer, src));
          }
      }
    }
  }

  void _addDrawnPolyline(
      List<Offset> pts, bool closed, String layer, SnapSource source) {
    if (pts.isEmpty) return;
    for (final p in pts) {
      _vertices.add(_V(p, layer, source));
    }
    final n = pts.length;
    final count = closed ? n : n - 1;
    for (var i = 0; i < count; i++) {
      _addSeg(pts[i], pts[(i + 1) % n], layer, perp: true, source: source);
    }
  }

  /// Источник пересечения: одинаковые → тот же, разные → «смешанное».
  SnapSource _mix(SnapSource a, SnapSource b) => a == b ? a : SnapSource.mixed;

  /// Геометрия дуги по bulge-сегменту (как при отрисовке полилиний).
  ({Offset c, double r, double start, double sweep})? _bulgeGeometry(
    double x1,
    double y1,
    double x2,
    double y2,
    double bulge,
  ) {
    if (bulge.abs() < 1e-9) return null;
    final dx = x2 - x1, dy = y2 - y1;
    final chord = math.sqrt(dx * dx + dy * dy);
    if (chord < _eps) return null;
    final theta = 4 * math.atan(bulge);
    final sinHalf = math.sin(theta.abs() / 2);
    if (sinHalf.abs() < 1e-12) return null;
    final r = chord / (2 * sinHalf);
    final mid = Offset((x1 + x2) / 2, (y1 + y2) / 2);
    final ux = dx / chord, uy = dy / chord;
    final nx = -uy, ny = ux;
    final h = math.sqrt(math.max(0.0, r * r - (chord * chord) / 4));
    final c1 = Offset(mid.dx + nx * h, mid.dy + ny * h);
    final c2 = Offset(mid.dx - nx * h, mid.dy - ny * h);
    Offset? center;
    double? sweep;
    for (final c in [c1, c2]) {
      final s = _signedSweep(c, Offset(x1, y1), Offset(x2, y2), theta);
      if (center == null || (s - theta).abs() < (sweep! - theta).abs()) {
        center = c;
        sweep = s;
      }
    }
    if (center == null || sweep == null) return null;
    final start = math.atan2(y1 - center.dy, x1 - center.dx);
    return (c: center, r: r, start: start, sweep: sweep);
  }

  double _signedSweep(Offset c, Offset p1, Offset p2, double theta) {
    final a1 = math.atan2(p1.dy - c.dy, p1.dx - c.dx);
    final a2 = math.atan2(p2.dy - c.dy, p2.dx - c.dx);
    var d = a2 - a1;
    while (d <= -math.pi) {
      d += _twoPi;
    }
    while (d > math.pi) {
      d -= _twoPi;
    }
    if (theta > 0 && d < 0) d += _twoPi;
    if (theta < 0 && d > 0) d -= _twoPi;
    return d;
  }

  Offset _pt(Offset c, double r, double a) =>
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));

  // ---------- запрос ----------

  /// Ищет привязку к [world] (мировые координаты DXF).
  ///
  /// [tolerance] — допуск в мировых единицах.
  /// [from] — предыдущая точка измерения (для перпендикуляра).
  /// [hiddenLayers] — скрытые слои (кандидаты с них не предлагаются).
  SnapResult? query(
    Offset world, {
    required double tolerance,
    Offset? from,
    Set<String> hiddenLayers = const {},
    SnapSettings? settings,
  }) {
    final snap = settings ?? SnapSettings();
    if (!snap.enabled) return null;
    if (world.dx.isNaN || world.dy.isNaN) return null;
    final tol = tolerance <= 0 ? 0.0 : tolerance;
    final tol2 = tol * tol;

    Offset? best;
    SnapType? bestType;
    SnapSource? bestSource;
    double bestD2 = double.infinity;

    double d2(Offset p) {
      final dx = p.dx - world.dx;
      final dy = p.dy - world.dy;
      return dx * dx + dy * dy;
    }

    void consider(Offset p, SnapType type, String layer, SnapSource source) {
      if (hiddenLayers.contains(layer)) return;
      final candidate = d2(p);
      if (candidate <= tol2 && candidate < bestD2) {
        bestD2 = candidate;
        best = p;
        bestType = type;
        bestSource = source;
      }
    }

    SnapResult? result() {
      if (best == null) return null;
      return SnapResult(
        point: best!,
        type: bestType!,
        distance: math.sqrt(bestD2),
        source: bestSource ?? SnapSource.dxf,
      );
    }

    // 1) вершины и точки — высший приоритет.
    if (snap.vertex) {
      for (final v in _vertices) {
        consider(v.p, SnapType.vertex, v.layer, v.source);
      }
    }
    if (snap.point) {
      for (final p in _points) {
        consider(p.p, SnapType.point, p.layer, p.source);
      }
    }
    final top = result();
    if (top != null) return top;

    final probe = Rect.fromCircle(center: world, radius: tol + 1e-6);

    // 2) пересечения фигур: сегмент-сегмент, сегмент-дуга, дуга-дуга.
    if (snap.intersection) {
      final segs = <_Seg>[];
      for (final s in _segments) {
        if (hiddenLayers.contains(s.layer) || !s.box.overlaps(probe)) continue;
        segs.add(s);
      }
      final arcs = <_Arc>[];
      for (final a in _arcs) {
        if (hiddenLayers.contains(a.layer) || !a.box.overlaps(probe)) continue;
        arcs.add(a);
      }
      for (var i = 0; i < segs.length; i++) {
        for (var j = i + 1; j < segs.length; j++) {
          // Соседние сегменты (общая вершина) — не «пересечение».
          if (_segShared(segs[i], segs[j])) continue;
          final p = _segmentIntersection(segs[i], segs[j]);
          if (p != null) {
            consider(p, SnapType.intersection, segs[i].layer,
                _mix(segs[i].source, segs[j].source));
          }
        }
        for (final a in arcs) {
          final fullArc = a.sweep.abs() >= _twoPi - 1e-6;
          for (final p in _segmentArcIntersections(segs[i], a)) {
            if (_same(p, segs[i].a) ||
                _same(p, segs[i].b) ||
                (!fullArc &&
                    (_same(p, _arcStart(a)) || _same(p, _arcEnd(a))))) {
              continue;
            }
            consider(p, SnapType.intersection, segs[i].layer,
                _mix(segs[i].source, a.source));
          }
        }
      }
      for (var i = 0; i < arcs.length; i++) {
        final full1 = arcs[i].sweep.abs() >= _twoPi - 1e-6;
        for (var j = i + 1; j < arcs.length; j++) {
          final full2 = arcs[j].sweep.abs() >= _twoPi - 1e-6;
          for (final p in _arcIntersections(arcs[i], arcs[j])) {
            if ((!full1 &&
                    (_same(p, _arcStart(arcs[i])) ||
                        _same(p, _arcEnd(arcs[i])))) ||
                (!full2 &&
                    (_same(p, _arcStart(arcs[j])) ||
                        _same(p, _arcEnd(arcs[j]))))) {
              continue;
            }
            consider(p, SnapType.intersection, arcs[i].layer,
                _mix(arcs[i].source, arcs[j].source));
          }
        }
      }
      // Пересечения бесконечных прямых (XLINE/RAY) с отрезками, дугами и между
      // собой.
      if (_infiniteLines.isNotEmpty) {
        final lines = [
          for (final l in _infiniteLines)
            if (!hiddenLayers.contains(l.layer)) l,
        ];
        for (final l in lines) {
          for (final s in segs) {
            final p = _lineSegmentIntersection(l, s);
            if (p != null) {
              consider(
                  p, SnapType.intersection, l.layer, _mix(l.source, s.source));
            }
          }
          for (final a in arcs) {
            final fullArc = a.sweep.abs() >= _twoPi - 1e-6;
            for (final p in _lineArcIntersections(l, a)) {
              if (!fullArc &&
                  (_same(p, _arcStart(a)) || _same(p, _arcEnd(a)))) {
                continue;
              }
              consider(
                  p, SnapType.intersection, l.layer, _mix(l.source, a.source));
            }
          }
        }
        for (var i = 0; i < lines.length; i++) {
          for (var j = i + 1; j < lines.length; j++) {
            final p = _lineLineIntersection(lines[i], lines[j]);
            if (p != null) {
              consider(p, SnapType.intersection, lines[i].layer,
                  _mix(lines[i].source, lines[j].source));
            }
          }
        }
      }
      final inter = result();
      if (inter != null) return inter;
    }

    // 3) перпендикуляр от предыдущей точки.
    if (snap.perpendicular && from != null) {
      for (final s in _segments) {
        if (!s.perp ||
            hiddenLayers.contains(s.layer) ||
            !s.box.overlaps(probe)) {
          continue;
        }
        final foot = _perpendicularOnSegment(from, s);
        if (foot != null) {
          consider(foot, SnapType.perpendicular, s.layer, s.source);
        }
      }
      for (final arc in _arcs) {
        if (hiddenLayers.contains(arc.layer) || !arc.box.overlaps(probe)) {
          continue;
        }
        final ux = from.dx - arc.c.dx;
        final uy = from.dy - arc.c.dy;
        final len = math.sqrt(ux * ux + uy * uy);
        if (len <= _eps) continue;
        for (final sign in const [1.0, -1.0]) {
          final p = Offset(
            arc.c.dx + sign * arc.r * ux / len,
            arc.c.dy + sign * arc.r * uy / len,
          );
          if (_onArc(arc, math.atan2(p.dy - arc.c.dy, p.dx - arc.c.dx))) {
            consider(p, SnapType.perpendicular, arc.layer, arc.source);
          }
        }
      }
      for (final l in _infiniteLines) {
        if (hiddenLayers.contains(l.layer)) continue;
        final foot = _perpendicularOnLine(from, l);
        if (foot != null) {
          consider(foot, SnapType.perpendicular, l.layer, l.source);
        }
      }
      final perp = result();
      if (perp != null) return perp;
    }

    // 3) касательная от предыдущей точки (окружности/дуги, эллипсы).
    if (snap.tangent && from != null) {
      for (final arc in _arcs) {
        if (hiddenLayers.contains(arc.layer) || !arc.box.overlaps(probe)) {
          continue;
        }
        final dx = from.dx - arc.c.dx;
        final dy = from.dy - arc.c.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d <= arc.r + 1e-9) continue; // точка внутри/на окружности
        final theta = math.atan2(dy, dx);
        final delta = math.acos((arc.r / d).clamp(-1.0, 1.0));
        for (final sign in const [-1.0, 1.0]) {
          final angle = theta + sign * delta;
          if (!_onArc(arc, angle)) continue;
          consider(_pt(arc.c, arc.r, angle), SnapType.tangent, arc.layer,
              arc.source);
        }
      }
      for (final el in _ellipses) {
        if (hiddenLayers.contains(el.layer) || !el.box.overlaps(probe)) {
          continue;
        }
        for (final t in _ellipseTangentRoots(el, from)) {
          consider(
              _ellipsePoint(el, t), SnapType.tangent, el.layer, SnapSource.dxf);
        }
      }
      final tangent = result();
      if (tangent != null) return tangent;
    }

    // 4) ближайшая точка на геометрии.
    if (snap.nearest) {
      for (final s in _segments) {
        if (hiddenLayers.contains(s.layer) || !s.box.overlaps(probe)) continue;
        consider(_closestOnSegment(world, s.a, s.b), SnapType.nearest, s.layer,
            s.source);
      }
      for (final arc in _arcs) {
        if (hiddenLayers.contains(arc.layer) || !arc.box.overlaps(probe)) {
          continue;
        }
        final angle = math.atan2(world.dy - arc.c.dy, world.dx - arc.c.dx);
        if (_onArc(arc, angle)) {
          consider(_pt(arc.c, arc.r, angle), SnapType.nearest, arc.layer,
              arc.source);
        }
      }
      for (final l in _infiniteLines) {
        if (hiddenLayers.contains(l.layer)) continue;
        final t = (world - l.p).dx * l.u.dx + (world - l.p).dy * l.u.dy;
        if (!l.allows(t)) continue;
        consider(l.pointAt(t), SnapType.nearest, l.layer, l.source);
      }
    }
    return result();
  }

  Offset? _perpendicularOnSegment(Offset from, _Seg s) {
    final ab = s.b - s.a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 <= 1e-18) return null;
    final t = ((from.dx - s.a.dx) * ab.dx + (from.dy - s.a.dy) * ab.dy) / len2;
    if (t < 0 || t > 1) return null;
    return Offset(s.a.dx + ab.dx * t, s.a.dy + ab.dy * t);
  }

  /// Основание перпендикуляра из [from] на бесконечную прямую.
  Offset? _perpendicularOnLine(Offset from, _Line l) {
    final t = (from - l.p).dx * l.u.dx + (from - l.p).dy * l.u.dy;
    if (!l.allows(t)) return null;
    return l.pointAt(t);
  }

  /// Пересечение бесконечной прямой/луча с отрезком.
  Offset? _lineSegmentIntersection(_Line l, _Seg s) {
    final d = s.b - s.a;
    final den = l.u.dx * d.dy - l.u.dy * d.dx;
    if (den.abs() < 1e-12) return null;
    final q = s.a - l.p;
    final t = (q.dx * d.dy - q.dy * d.dx) / den;
    final u = (q.dx * l.u.dy - q.dy * l.u.dx) / den;
    if (u < -1e-9 || u > 1 + 1e-9) return null;
    if (!l.allows(t)) return null;
    return l.pointAt(t);
  }

  /// Пересечения бесконечной прямой/луча с дугой/окружностью.
  List<Offset> _lineArcIntersections(_Line l, _Arc arc) {
    final f = l.p - arc.c;
    final b2 = 2 * (f.dx * l.u.dx + f.dy * l.u.dy);
    final c2 = f.dx * f.dx + f.dy * f.dy - arc.r * arc.r;
    final disc = b2 * b2 - 4 * c2;
    if (disc < 0) return const [];
    final sq = math.sqrt(disc);
    final out = <Offset>[];
    for (final t in [(-b2 - sq) / 2, (-b2 + sq) / 2]) {
      if (!l.allows(t)) continue;
      final p = l.pointAt(t);
      final ang = math.atan2(p.dy - arc.c.dy, p.dx - arc.c.dx);
      if (_onArc(arc, ang)) out.add(p);
    }
    return out;
  }

  /// Пересечение двух бесконечных прямых/лучей.
  Offset? _lineLineIntersection(_Line a, _Line b) {
    final den = a.u.dx * b.u.dy - a.u.dy * b.u.dx;
    if (den.abs() < 1e-12) return null;
    final q = b.p - a.p;
    final t = (q.dx * b.u.dy - q.dy * b.u.dx) / den;
    final s = (q.dx * a.u.dy - q.dy * a.u.dx) / den;
    if (!a.allows(t) || !b.allows(s)) return null;
    return a.pointAt(t);
  }

  Offset _closestOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 <= 1e-18) return a;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  Offset _ellipsePoint(_Ellipse el, double t) => Offset(
        el.c.dx + el.major.dx * math.cos(t) + el.minor.dx * math.sin(t),
        el.c.dy + el.major.dy * math.cos(t) + el.minor.dy * math.sin(t),
      );

  Offset _ellipseTangentVector(_Ellipse el, double t) => Offset(
        -el.major.dx * math.sin(t) + el.minor.dx * math.cos(t),
        -el.major.dy * math.sin(t) + el.minor.dy * math.cos(t),
      );

  /// Условие касательности: (E(t) − P) × E'(t) = 0.
  double _ellipseTangentF(_Ellipse el, Offset p, double t) {
    final e = _ellipsePoint(el, t);
    final d = _ellipseTangentVector(el, t);
    return (e.dx - p.dx) * d.dy - (e.dy - p.dy) * d.dx;
  }

  /// Корни условия касательности на видимом участке эллипса.
  List<double> _ellipseTangentRoots(_Ellipse el, Offset p) {
    final roots = <double>[];
    const steps = 128;
    double? prevT;
    double? prevF;
    for (var i = 0; i <= steps; i++) {
      final t = el.start + (el.end - el.start) * i / steps;
      final ft = _ellipseTangentF(el, p, t);
      if (prevT != null && prevF != null && prevF * ft <= 0) {
        var lo = prevT;
        var hi = t;
        var flo = prevF;
        for (var k = 0; k < 40; k++) {
          final mid = (lo + hi) / 2;
          final fm = _ellipseTangentF(el, p, mid);
          if (flo * fm <= 0) {
            hi = mid;
          } else {
            lo = mid;
            flo = fm;
          }
        }
        roots.add((lo + hi) / 2);
      }
      prevT = t;
      prevF = ft;
    }
    return roots;
  }

  // ---------- пересечения фигур ----------

  bool _same(Offset a, Offset b) => (a - b).distance < 1e-9;

  bool _segShared(_Seg s1, _Seg s2) =>
      _same(s1.a, s2.a) ||
      _same(s1.a, s2.b) ||
      _same(s1.b, s2.a) ||
      _same(s1.b, s2.b);

  Offset _arcStart(_Arc a) => _pt(a.c, a.r, a.start);

  Offset _arcEnd(_Arc a) => _pt(a.c, a.r, a.start + a.sweep);

  Offset? _segmentIntersection(_Seg s1, _Seg s2) {
    final d1 = s1.b - s1.a;
    final d2 = s2.b - s2.a;
    final den = d1.dx * d2.dy - d1.dy * d2.dx;
    if (den.abs() < 1e-12) return null;
    final t = ((s2.a.dx - s1.a.dx) * d2.dy - (s2.a.dy - s1.a.dy) * d2.dx) / den;
    final u = ((s2.a.dx - s1.a.dx) * d1.dy - (s2.a.dy - s1.a.dy) * d1.dx) / den;
    if (t < -1e-9 || t > 1 + 1e-9 || u < -1e-9 || u > 1 + 1e-9) {
      return null;
    }
    return Offset(s1.a.dx + d1.dx * t, s1.a.dy + d1.dy * t);
  }

  List<Offset> _segmentArcIntersections(_Seg s, _Arc arc) {
    final d = s.b - s.a;
    final a2 = d.dx * d.dx + d.dy * d.dy;
    if (a2 < 1e-18) return const [];
    final f = s.a - arc.c;
    final b2 = 2 * (f.dx * d.dx + f.dy * d.dy);
    final c2 = f.dx * f.dx + f.dy * f.dy - arc.r * arc.r;
    final disc = b2 * b2 - 4 * a2 * c2;
    if (disc < 0) return const [];
    final sq = math.sqrt(disc);
    final out = <Offset>[];
    for (final t in [(-b2 - sq) / (2 * a2), (-b2 + sq) / (2 * a2)]) {
      if (t < -1e-9 || t > 1 + 1e-9) continue;
      final p = Offset(s.a.dx + d.dx * t, s.a.dy + d.dy * t);
      final ang = math.atan2(p.dy - arc.c.dy, p.dx - arc.c.dx);
      if (_onArc(arc, ang)) out.add(p);
    }
    return out;
  }

  List<Offset> _arcIntersections(_Arc a1, _Arc a2) {
    final d = a2.c - a1.c;
    final dist = d.distance;
    if (dist < 1e-9) return const [];
    if (dist > a1.r + a2.r + 1e-9) return const [];
    if (dist < (a1.r - a2.r).abs() - 1e-9) return const [];
    final a = (a1.r * a1.r - a2.r * a2.r + dist * dist) / (2 * dist);
    final h2 = a1.r * a1.r - a * a;
    if (h2 < 0) return const [];
    final h = math.sqrt(h2);
    final ux = d.dx / dist;
    final uy = d.dy / dist;
    final mid = Offset(a1.c.dx + ux * a, a1.c.dy + uy * a);
    final out = <Offset>[];
    for (final sign in const [1.0, -1.0]) {
      final p = Offset(mid.dx - uy * h * sign, mid.dy + ux * h * sign);
      final ang1 = math.atan2(p.dy - a1.c.dy, p.dx - a1.c.dx);
      final ang2 = math.atan2(p.dy - a2.c.dy, p.dx - a2.c.dx);
      if (_onArc(a1, ang1) && _onArc(a2, ang2)) out.add(p);
    }
    return out;
  }

  bool _onArc(_Arc arc, double angle) {
    final absSweep = arc.sweep.abs();
    if (absSweep >= _twoPi - 1e-6) return true;
    var d = arc.sweep >= 0 ? angle - arc.start : arc.start - angle;
    d %= _twoPi;
    if (d < 0) d += _twoPi;
    return d <= absSweep + 1e-6;
  }
}

class _V {
  final Offset p;
  final String layer;
  final SnapSource source;
  const _V(this.p, this.layer, [this.source = SnapSource.dxf]);
}

class _Seg {
  final Offset a, b;
  final String layer;
  final bool perp;
  final Rect box;
  final SnapSource source;
  const _Seg({
    required this.a,
    required this.b,
    required this.layer,
    required this.perp,
    required this.box,
    this.source = SnapSource.dxf,
  });
}

class _Arc {
  final Offset c;
  final double r, start, sweep;
  final String layer;
  final Rect box;
  final SnapSource source;
  const _Arc({
    required this.c,
    required this.r,
    required this.start,
    required this.sweep,
    required this.layer,
    required this.box,
    this.source = SnapSource.dxf,
  });
}

class _Ellipse {
  final Offset c, major, minor;
  final double start, end;
  final String layer;
  final Rect box;
  const _Ellipse({
    required this.c,
    required this.major,
    required this.minor,
    required this.start,
    required this.end,
    required this.layer,
    required this.box,
  });
}

/// Бесконечная прямая (XLINE) или луч (RAY) с единичным направлением.
class _Line {
  final Offset p;
  final Offset u;
  final bool infinite;
  final String layer;
  final SnapSource source;
  const _Line(this.p, this.u, this.infinite, this.layer,
      [this.source = SnapSource.dxf]);

  Offset pointAt(double t) => Offset(p.dx + u.dx * t, p.dy + u.dy * t);

  /// Для луча — только вперёд (t >= 0).
  bool allows(double t) => infinite || t >= -1e-9;
}
