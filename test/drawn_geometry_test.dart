import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/utils/bulge_arc.dart';
import 'package:menzulka/utils/drawn_geometry.dart';

bool _outside(Offset p, Offset leftBottom, Offset rightTop) {
  const margin = 0.5;
  return p.dx < leftBottom.dx - margin ||
      p.dx > rightTop.dx + margin ||
      p.dy < leftBottom.dy - margin ||
      p.dy > rightTop.dy + margin;
}

void main() {
  test('облако — равные радиусы и дуги наружу', () {
    final corners = rectangleCorners(const Offset(0, 0), const Offset(100, 60));
    final cloud = buildCloud(corners);
    expect(cloud.vertices.length, greaterThanOrEqualTo(8));
    expect(cloud.vertices.length, lessThanOrEqualTo(80));
    expect(cloud.bulges.length, cloud.vertices.length);
    expect(cloud.bulges.every((b) => b > 0), isTrue);

    final radii = <double>[];
    for (var i = 0; i < cloud.vertices.length; i++) {
      final a = cloud.vertices[i];
      final b = cloud.vertices[(i + 1) % cloud.vertices.length];
      final chord = (b - a).distance;
      final theta = 4 * math.atan(cloud.bulges[i].abs());
      radii.add(chord / (2 * math.sin(theta / 2)));
    }
    final mean = radii.reduce((a, b) => a + b) / radii.length;
    for (final r in radii) {
      expect((r - mean).abs() / mean, lessThan(0.05));
    }

    // Середина каждой дуги — снаружи прямоугольника.
    for (var i = 0; i < cloud.vertices.length; i++) {
      final a = cloud.vertices[i];
      final b = cloud.vertices[(i + 1) % cloud.vertices.length];
      final pts = bulgeArcPoints(
        a.dx,
        a.dy,
        b.dx,
        b.dy,
        cloud.bulges[i],
        segments: 16,
      );
      final mid = pts[pts.length ~/ 2];
      expect(_outside(mid, const Offset(0, 0), const Offset(100, 60)), isTrue);
    }
  });

  test('облако — квадрат и вытянутый прямоугольник', () {
    for (final rect in [
      [const Offset(0, 0), const Offset(80, 80)],
      [const Offset(-5, 10), const Offset(195, 18)],
    ]) {
      final cloud = buildCloud(rectangleCorners(rect[0], rect[1]));
      final radii = <double>[];
      for (var i = 0; i < cloud.vertices.length; i++) {
        final a = cloud.vertices[i];
        final b = cloud.vertices[(i + 1) % cloud.vertices.length];
        final chord = (b - a).distance;
        final theta = 4 * math.atan(cloud.bulges[i].abs());
        radii.add(chord / (2 * math.sin(theta / 2)));
      }
      final mean = radii.reduce((a, b) => a + b) / radii.length;
      for (final r in radii) {
        expect((r - mean).abs() / mean, lessThan(0.05));
      }
    }
  });

  test('прямоугольник из двух точек — любой порядок', () {
    final a = rectangleCorners(const Offset(10, 20), const Offset(30, 5));
    final b = rectangleCorners(const Offset(30, 5), const Offset(10, 20));
    expect(a, b);
    expect(a.first, const Offset(10, 5));
    expect(a[2], const Offset(30, 20));
  });

  test('размер — линия параллельна, текст вдоль и снаружи', () {
    final l = layoutDimension(
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(50, 20),
      textHeight: 2.5,
    );
    expect(l, isNotNull);
    expect(l!.dimStart.dy, closeTo(20, 1e-9));
    expect(l.dimEnd.dy, closeTo(20, 1e-9));
    expect(l.dimStart.dx, closeTo(0, 1e-9));
    expect(l.dimEnd.dx, closeTo(100, 1e-9));
    expect(l.textAngleDeg, closeTo(0, 1e-6));
    expect(l.textPosition.dy, greaterThan(20));
    expect(l.length, closeTo(100, 1e-9));
    // Выносные выходят за размерную линию.
    expect(l.ext1End.dy, greaterThan(20));
    expect(l.ext2End.dy, greaterThan(20));
  });

  test('размер — наклонная линия 45°', () {
    final l = layoutDimension(
      const Offset(0, 0),
      const Offset(100, 100),
      const Offset(0, 60),
      textHeight: 2.5,
    );
    expect(l, isNotNull);
    expect(l!.textAngleDeg, closeTo(45, 1e-6));
    // Размерная линия параллельна p1p2.
    final d1 = l.dimEnd - l.dimStart;
    expect(d1.dy / d1.dx, closeTo(1, 1e-6));
  });

  test('размер — текст не вверх ногами (угол в (-90, 90])', () {
    final l = layoutDimension(
      const Offset(100, 0),
      const Offset(0, 0),
      const Offset(50, -20),
      textHeight: 2.5,
    );
    expect(l, isNotNull);
    expect(l!.textAngleDeg, closeTo(0, 1e-6));

    final v = layoutDimension(
      const Offset(0, 100),
      const Offset(0, 0),
      const Offset(-20, 50),
      textHeight: 2.5,
    );
    expect(v, isNotNull);
    expect(v!.textAngleDeg, greaterThan(-90.000001));
    expect(v.textAngleDeg, lessThanOrEqualTo(90));
  });

  test('размер — вырожденные точки отбрасываются', () {
    expect(layoutDimension(Offset.zero, Offset.zero, Offset.zero), isNull);
  });

  test('облако по произвольному контуру — равные радиусы и наружу', () {
    final triangle = [
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(50, 80),
    ];
    final cloud = buildCloudFromPolygon(triangle);
    expect(cloud.vertices.length, greaterThanOrEqualTo(8));
    expect(cloud.bulges.length, cloud.vertices.length);
    final radii = <double>[];
    for (var i = 0; i < cloud.vertices.length; i++) {
      final a = cloud.vertices[i];
      final b = cloud.vertices[(i + 1) % cloud.vertices.length];
      final chord = (b - a).distance;
      final theta = 4 * math.atan(cloud.bulges[i].abs());
      radii.add(chord / (2 * math.sin(theta / 2)));
    }
    final mean = radii.reduce((a, b) => a + b) / radii.length;
    for (final r in radii) {
      expect((r - mean).abs() / mean, lessThan(0.05));
    }
    for (var i = 0; i < cloud.vertices.length; i++) {
      final a = cloud.vertices[i];
      final b = cloud.vertices[(i + 1) % cloud.vertices.length];
      final pts =
          bulgeArcPoints(a.dx, a.dy, b.dx, b.dy, cloud.bulges[i], segments: 16);
      final mid = pts[pts.length ~/ 2];
      expect(
        _insideTriangle(mid, triangle[0], triangle[1], triangle[2]),
        isFalse,
      );
    }
  });

  test('облако по контуру — обратный порядок точек', () {
    final cw = [
      const Offset(0, 0),
      const Offset(50, 80),
      const Offset(100, 0),
    ];
    final cloud = buildCloudFromPolygon(cw);
    expect(cloud.vertices.length, greaterThanOrEqualTo(8));
    expect(cloud.bulges.every((b) => b > 0), isTrue);
  });

  test('дуги облака на 30% глубже', () {
    final cloud = buildCloud(
      rectangleCorners(const Offset(0, 0), const Offset(100, 60)),
    );
    expect(cloud.bulges.length, cloud.vertices.length);
    expect(
      cloud.bulges.every((b) => (b - kCloudArcScale).abs() < 1e-9),
      isTrue,
    );
    for (var i = 0; i < cloud.vertices.length; i++) {
      final a = cloud.vertices[i];
      final b = cloud.vertices[(i + 1) % cloud.vertices.length];
      final chord = (b - a).distance;
      final pts = bulgeArcPoints(
        a.dx,
        a.dy,
        b.dx,
        b.dy,
        cloud.bulges[i],
        segments: 64,
      );
      final mid = pts[pts.length ~/ 2];
      final dir = (b - a) / chord;
      final t = (mid - a).dx * dir.dx + (mid - a).dy * dir.dy;
      final onChord = a + dir * t.clamp(0.0, chord);
      final sagitta = (mid - onChord).distance;
      // Стрелка прогиба = (bulge / 2) * хорда = 0.65 * хорда.
      expect(sagitta / chord, closeTo(kCloudArcScale / 2, 0.1));
    }
  });

  test('полка размера по умолчанию — над отрезком', () {
    final shelf =
        defaultDimensionShelf(const Offset(0, 0), const Offset(100, 0), 40);
    expect(shelf.dx, closeTo(50, 1e-9));
    expect(shelf.dy, closeTo(40, 1e-9));

    final vertical =
        defaultDimensionShelf(const Offset(0, 0), const Offset(0, 100), 40);
    expect(vertical.dy, closeTo(50, 1e-9));
    expect(vertical.dx, closeTo(40, 1e-9));
  });

  test('прямая обрезается по видимой области', () {
    const rect = Rect.fromLTRB(-10, -10, 10, 10);
    final horizontal = clipLineToRect(Offset.zero, const Offset(1, 0), rect);
    expect(horizontal, isNotNull);
    expect(horizontal!.start, const Offset(-10, 0));
    expect(horizontal.end, const Offset(10, 0));

    final vertical =
        clipLineToRect(const Offset(5, 0), const Offset(0, 1), rect);
    expect(vertical, isNotNull);
    expect(vertical!.start, const Offset(5, -10));
    expect(vertical.end, const Offset(5, 10));

    expect(
      clipLineToRect(const Offset(0, 50), const Offset(1, 0), rect),
      isNull,
    );

    final diagonal = clipLineToRect(
      Offset.zero,
      const Offset(1, 1) / math.sqrt2,
      rect,
    );
    expect(diagonal, isNotNull);
    expect(diagonal!.start.dx, closeTo(-10, 1e-6));
    expect(diagonal.end.dx, closeTo(10, 1e-6));
  });
}

bool _insideTriangle(Offset p, Offset a, Offset b, Offset c) {
  double sign(Offset p1, Offset p2, Offset p3) =>
      (p1.dx - p3.dx) * (p2.dy - p3.dy) - (p2.dx - p3.dx) * (p1.dy - p3.dy);
  final d1 = sign(p, a, b);
  final d2 = sign(p, b, c);
  final d3 = sign(p, c, a);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}
