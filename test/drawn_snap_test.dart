import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/drawn_object.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/services/drawn_snap.dart';

void main() {
  DrawnObject obj(DrawnType type, List<Offset> points, {String id = 'o'}) =>
      DrawnObject(
        id: id,
        drawingId: 'd',
        type: type,
        points: points,
        createdAt: DateTime(2026, 10, 30),
      );

  test('вершина нарисованного отрезка', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.line, const [Offset(0, 0), Offset(100, 0)]),
    ]);
    final r = index.query(const Offset(2, 1), tolerance: 5);
    expect(r, isNotNull);
    expect(r!.type, SnapType.vertex);
    expect(r.point, const Offset(0, 0));
  });

  test('ближайшая на середине отрезка', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.line, const [Offset(0, 0), Offset(100, 0)]),
    ]);
    final r = index.query(const Offset(50, 3), tolerance: 5);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(50, 0.01));
    expect(r.point.dy, closeTo(0, 0.01));
  });

  test('нарисованная точка — узел', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.point, const [Offset(10, 10)]),
    ]);
    final r = index.query(const Offset(11, 10), tolerance: 5);
    expect(r, isNotNull);
    expect(r!.type, SnapType.point);
  });

  test('круг — ближайшая точка по радиусу', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.circle, const [Offset(0, 0), Offset(10, 0)]),
    ]);
    final r = index.query(const Offset(10.5, 0), tolerance: 5);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(10, 1e-6));
    expect(r.point.dy, closeTo(0, 1e-6));
  });

  test('прямая — привязка по всей бесконечной линии', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.ray, const [Offset(0, 0), Offset(1, 0)]),
    ]);
    final r = index.query(const Offset(1000, 1), tolerance: 5);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(1000, 1e-6));
    expect(r.point.dy, closeTo(0, 1e-6));
  });

  test('прямоугольник — вершины и ближайшая на стороне', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.rectangle, const [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 10),
        Offset(0, 10),
      ]),
    ]);
    final vertex = index.query(const Offset(0.5, 0.5), tolerance: 3);
    expect(vertex!.type, SnapType.vertex);
    final edge = index.query(const Offset(5, 0.5), tolerance: 3);
    expect(edge!.type, SnapType.nearest);
    expect(edge.point.dy, closeTo(0, 1e-6));
  });

  test('пересечение нарисованных отрезков', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.line, const [Offset(0, 0), Offset(10, 10)], id: 'a'),
      obj(DrawnType.line, const [Offset(0, 10), Offset(10, 0)], id: 'b'),
    ]);
    final r = index.query(const Offset(5.2, 5.1), tolerance: 1);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(5, 1e-6));
    expect(r.point.dy, closeTo(5, 1e-6));
  });

  test('пересечение нарисованного отрезка и круга', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.line, const [Offset(-5, 0), Offset(5, 0)]),
      obj(DrawnType.circle, const [Offset(0, 0), Offset(3, 0)]),
    ]);
    final r = index.query(const Offset(3.1, 0.2), tolerance: 1);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(3, 1e-6));
    expect(r.point.dy, closeTo(0, 1e-6));
  });

  test('вне допуска — null', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.point, const [Offset(10, 10)]),
    ]);
    final r = index.query(const Offset(30, 10), tolerance: 5);
    expect(r, isNull);
  });

  test('текст рисунка — вершина, источник drawn', () {
    final index = DrawnSnapIndex([
      DrawnObject(
        id: 't',
        drawingId: 'd',
        type: DrawnType.text,
        points: const [Offset(10, 20)],
        text: 'X',
        createdAt: DateTime(2026, 10, 30),
      ),
    ]);
    final r = index.query(const Offset(10.5, 20.4), tolerance: 2);
    expect(r, isNotNull);
    expect(r!.type, SnapType.vertex);
    expect(r.source, SnapSource.drawn);
  });

  test('источник привязки — drawn для вершины отрезка', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.line, const [Offset(0, 0), Offset(100, 0)]),
    ]);
    final r = index.query(const Offset(2, 1), tolerance: 5);
    expect(r, isNotNull);
    expect(r!.source, SnapSource.drawn);
  });

  test('ближайшая на нарисованной прямой', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.ray, const [Offset(0, 0), Offset(1, 0)]),
    ]);
    final r = index.query(const Offset(30, 0.3), tolerance: 1);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(30, 1e-6));
    expect(r.point.dy, closeTo(0, 1e-6));
  });

  test('пересечение нарисованной прямой и отрезка', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.ray, const [Offset(5, 5), Offset(6, 5)]),
      obj(DrawnType.line, const [Offset(20, -10), Offset(20, 10)], id: 'l'),
    ]);
    final r = index.query(const Offset(20.2, 5.2), tolerance: 1);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(20, 1e-6));
    expect(r.point.dy, closeTo(5, 1e-6));
  });

  test('перпендикуляр к нарисованной прямой', () {
    final index = DrawnSnapIndex([
      obj(DrawnType.ray, const [Offset(0, 0), Offset(1, 0)]),
    ]);
    final r = index.query(
      const Offset(5, 0.2),
      tolerance: 1,
      from: const Offset(5, 10),
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.perpendicular);
    expect(r.point.dx, closeTo(5, 1e-6));
    expect(r.point.dy, closeTo(0, 1e-6));
  });
}
