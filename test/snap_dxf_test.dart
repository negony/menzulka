import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/services/dxf_parser.dart';
import 'package:menzulka/services/snap_engine.dart';

/// Проверка привязок на реальном сгенерированном DXF
/// (`dart run tool/generate_snap_test_dxf.dart`).
void main() {
  final file = File('build/test_data/snap_test.dxf');

  test('snap_test.dxf: все примитивы', () async {
    if (!file.existsSync()) {
      // Генератор не запускался — тест пропускается.
      return;
    }
    final document = await DxfParser().parseBytes(file.readAsBytesSync());
    final engine = SnapEngine(document);

    // LINE (100,100)-(300,100): вершина.
    final lineEnd = engine.query(const Offset(101, 101), tolerance: 2);
    expect(lineEnd, isNotNull);
    expect(lineEnd!.type, SnapType.vertex);
    expect(lineEnd.point.dx, closeTo(100, 1e-6));
    expect(lineEnd.point.dy, closeTo(100, 1e-6));

    // Прямоугольник: угол (600,250).
    final rectCorner = engine.query(const Offset(599, 249), tolerance: 2);
    expect(rectCorner, isNotNull);
    expect(rectCorner!.type, SnapType.vertex);
    expect(rectCorner.point.dx, closeTo(600, 1e-6));
    expect(rectCorner.point.dy, closeTo(250, 1e-6));

    // Старая POLYLINE: вершина (800,200).
    final polyVertex = engine.query(const Offset(801, 201), tolerance: 2);
    expect(polyVertex, isNotNull);
    expect(polyVertex!.type, SnapType.vertex);
    expect(polyVertex.point.dx, closeTo(800, 1e-6));

    // ARC: конец (150,480).
    final arcEnd = engine.query(const Offset(151, 479), tolerance: 2);
    expect(arcEnd, isNotNull);
    expect(arcEnd!.type, SnapType.vertex);
    expect(arcEnd.point.dx, closeTo(150, 1e-6));
    expect(arcEnd.point.dy, closeTo(480, 1e-6));

    // CIRCLE: ближайшая (400,460).
    final circle = engine.query(const Offset(400, 459), tolerance: 2);
    expect(circle, isNotNull);
    expect(circle!.type, SnapType.nearest);
    expect(circle.point.dx, closeTo(400, 1e-6));
    expect(circle.point.dy, closeTo(460, 1e-6));

    // ELLIPSE: ближайшая точка рядом с правым концом (кривизна даёт ~401.05).
    final ellipse = engine.query(const Offset(799, 401), tolerance: 2);
    expect(ellipse, isNotNull);
    expect(ellipse!.type, SnapType.nearest);
    expect(ellipse.point.dx, closeTo(799.98, 0.3));
    expect(ellipse.point.dy, closeTo(401.05, 0.3));

    // POINT: узел (150,700).
    final point = engine.query(const Offset(151, 701), tolerance: 2);
    expect(point, isNotNull);
    expect(point!.type, SnapType.point);
    expect(point.point.dx, closeTo(150, 1e-6));
    expect(point.point.dy, closeTo(700, 1e-6));

    // BULGE-дуга: ближайшая (400,600).
    final bulge = engine.query(const Offset(400, 601), tolerance: 2);
    expect(bulge, isNotNull);
    expect(bulge!.type, SnapType.nearest);
    expect(bulge.point.dx, closeTo(400, 1e-6));
    expect(bulge.point.dy, closeTo(600, 1e-6));

    // INSERT: точка вставки (700,700).
    final insert = engine.query(const Offset(701, 701), tolerance: 2);
    expect(insert, isNotNull);
    expect(insert!.type, SnapType.point);
    expect(insert.point.dx, closeTo(700, 1e-6));
    expect(insert.point.dy, closeTo(700, 1e-6));

    // INSERT: геометрия блока — ближайшая на окружности r=12.
    // (708,708) — вне перекрестия блока, ближайшая точка окружности ~ (708.49,708.49).
    final blockCircle = engine.query(const Offset(708, 708), tolerance: 2);
    expect(blockCircle, isNotNull);
    expect(blockCircle!.type, SnapType.nearest);
    expect(blockCircle.point.dx, closeTo(708.485, 0.3));
    expect(blockCircle.point.dy, closeTo(708.485, 0.3));

    // Перпендикуляр от (150,300) к LINE.
    final perp = engine.query(
      const Offset(150.2, 100.2),
      tolerance: 2,
      from: const Offset(150, 300),
    );
    expect(perp, isNotNull);
    expect(perp!.type, SnapType.perpendicular);
    expect(perp.point.dx, closeTo(150, 1e-6));
    expect(perp.point.dy, closeTo(100, 1e-6));

    // Касательная от (700,700) к CIRCLE: точки касания ~ (448,364) и (364,448).
    final tangent = engine.query(
      const Offset(448, 364),
      tolerance: 2,
      from: const Offset(700, 700),
    );
    expect(tangent, isNotNull);
    expect(tangent!.type, SnapType.tangent);
    expect(tangent.point.dx, closeTo(448, 0.5));
    expect(tangent.point.dy, closeTo(364, 0.5));
  });
}
