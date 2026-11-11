import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/drawn_object.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/services/snap_engine.dart';

DxfDocument _doc(
  List<DxfEntity> entities, {
  Map<String, DxfBlock> blocks = const {},
}) =>
    DxfDocument(
      layers: const [],
      entities: entities,
      blocks: blocks,
      minX: 0,
      minY: 0,
      maxX: 100,
      maxY: 100,
    );

void main() {
  test('пересечение двух LINE', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
      DxfLine(layer: '0', x1: 0, y1: 10, x2: 10, y2: 0),
    ]));
    // Вершины далеко (> 1), пересечение (5,5) — в допуске.
    final r = engine.query(const Offset(5.2, 5.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(5, 1e-6));
    expect(r.point.dy, closeTo(5, 1e-6));
  });

  test('пересечение линии и окружности', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: -5, y1: 0, x2: 5, y2: 0),
      DxfCircle(layer: '0', cx: 0, cy: 0, radius: 3),
    ]));
    final r = engine.query(const Offset(3.1, 0.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(3, 1e-6));
    expect(r.point.dy, closeTo(0, 1e-6));
  });

  test('привязка «Пересечение» отключается настройкой', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
      DxfLine(layer: '0', x1: 0, y1: 10, x2: 10, y2: 0),
    ]));
    final settings = SnapSettings(nearest: false, intersection: false);
    final r = engine.query(
      const Offset(5.2, 5.2),
      tolerance: 1.0,
      settings: settings,
    );
    expect(r, isNull);
  });

  test('вершина LINE', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(const Offset(9.8, 0.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.vertex);
    expect(r.point.dx, closeTo(10, 1e-9));
    expect(r.point.dy, closeTo(0, 1e-9));
  });

  test('узел DxfPoint', () {
    final engine = SnapEngine(_doc([
      DxfPoint(layer: '0', x: 5, y: 5),
    ]));
    final r = engine.query(const Offset(5.2, 5.1), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.point);
    expect(r.point.dx, closeTo(5, 1e-9));
  });

  test('точка вставки INSERT', () {
    final block = DxfBlock(
      name: 'B',
      entities: [DxfLine(layer: '0', x1: 5, y1: 0, x2: 10, y2: 0)],
    );
    final engine = SnapEngine(_doc(
      [
        DxfInsert(
            layer: '0',
            blockName: 'B',
            x: 20,
            y: 20,
            scaleX: 2,
            scaleY: 2,
            rotation: 90)
      ],
      blocks: {'B': block},
    ));
    final r = engine.query(const Offset(20.2, 20.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.point);
    expect(r.point.dx, closeTo(20, 1e-9));
    expect(r.point.dy, closeTo(20, 1e-9));
  });

  test('геометрия блока с поворотом и масштабом', () {
    final block = DxfBlock(
      name: 'B',
      entities: [DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0)],
    );
    final engine = SnapEngine(_doc(
      [
        DxfInsert(
            layer: '0',
            blockName: 'B',
            x: 20,
            y: 20,
            scaleX: 2,
            scaleY: 2,
            rotation: 90)
      ],
      blocks: {'B': block},
    ));
    // (0,0) -> (20,20), (10,0) -> (20,40).
    final r = engine.query(const Offset(20.2, 39.8), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.vertex);
    expect(r.point.dx, closeTo(20, 1e-9));
    expect(r.point.dy, closeTo(40, 1e-9));
  });

  test('ближайшая на отрезке', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(const Offset(5, 2), tolerance: 3.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(5, 1e-9));
    expect(r.point.dy, closeTo(0, 1e-9));
  });

  test('ближайшая на окружности', () {
    final engine = SnapEngine(_doc([
      DxfCircle(layer: '0', cx: 50, cy: 50, radius: 10),
    ]));
    final r = engine.query(const Offset(50, 62), tolerance: 3.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(50, 1e-6));
    expect(r.point.dy, closeTo(60, 1e-6));
  });

  test('концы и ближайшая на дуге', () {
    final engine = SnapEngine(_doc([
      DxfArc(layer: '0', cx: 0, cy: 0, radius: 10, startAngle: 0, endAngle: 90),
    ]));
    final end = engine.query(const Offset(0.3, 10.2), tolerance: 1.0);
    expect(end, isNotNull);
    expect(end!.type, SnapType.vertex);
    expect(end.point.dx, closeTo(0, 1e-6));
    expect(end.point.dy, closeTo(10, 1e-6));

    final nearest = engine.query(const Offset(7.2, 7.2), tolerance: 1.0);
    expect(nearest, isNotNull);
    expect(nearest!.type, SnapType.nearest);
    expect(nearest.point.dx, closeTo(7.0710678, 1e-3));
    expect(nearest.point.dy, closeTo(7.0710678, 1e-3));
  });

  test('перпендикуляр к отрезку', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(
      const Offset(3.1, 0.1),
      tolerance: 1.0,
      from: const Offset(3, 5),
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.perpendicular);
    expect(r.point.dx, closeTo(3, 1e-9));
    expect(r.point.dy, closeTo(0, 1e-9));
  });

  test('перпендикуляр к окружности (радиальный)', () {
    final engine = SnapEngine(_doc([
      DxfCircle(layer: '0', cx: 50, cy: 50, radius: 10),
    ]));
    final r = engine.query(
      const Offset(50.2, 61),
      tolerance: 2.0,
      from: const Offset(50, 80),
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.perpendicular);
    expect(r.point.dx, closeTo(50, 1e-6));
    expect(r.point.dy, closeTo(60, 1e-6));
  });

  test('вершина приоритетнее ближайшей', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(const Offset(10.2, 0.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.vertex);
    expect(r.point.dx, closeTo(10, 1e-9));
  });

  test('ближайшая на bulge-дуге полилинии', () {
    final engine = SnapEngine(_doc([
      DxfLwPolyline(
        layer: '0',
        vertices: const [DxfVertex(0, 0, 1), DxfVertex(10, 0)],
      ),
    ]));
    // Положительный bulge: дуга CCW идёт ниже хорды в мировых координатах.
    final r = engine.query(const Offset(5, -5.4), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(5, 1e-2));
    expect(r.point.dy, closeTo(-5, 1e-1));
  });

  test('прямоугольник: вершина и сторона', () {
    final engine = SnapEngine(_doc([
      DxfLwPolyline(
        layer: '0',
        vertices: const [
          DxfVertex(0, 0),
          DxfVertex(10, 0),
          DxfVertex(10, 5),
          DxfVertex(0, 5),
        ],
        isClosed: true,
      ),
    ]));
    final corner = engine.query(const Offset(10.2, 5.2), tolerance: 1.0);
    expect(corner!.type, SnapType.vertex);
    expect(corner.point.dy, closeTo(5, 1e-9));

    final side = engine.query(const Offset(10.1, 2), tolerance: 1.0);
    expect(side!.type, SnapType.nearest);
    expect(side.point.dx, closeTo(10, 1e-9));
    expect(side.point.dy, closeTo(2, 1e-9));
  });

  test('эллипс: ближайшая точка', () {
    final engine = SnapEngine(_doc([
      DxfEllipse(
        layer: '0',
        cx: 50,
        cy: 50,
        majorX: 10,
        majorY: 0,
        ratio: 0.5,
      ),
    ]));
    final r = engine.query(const Offset(60.5, 50), tolerance: 2.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
    expect(r.point.dx, closeTo(60, 0.2));
    expect(r.point.dy, closeTo(50, 0.5));
  });

  test('скрытые слои не участвуют', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: 'HID', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(
      const Offset(9.9, 0.1),
      tolerance: 1.0,
      hiddenLayers: {'HID'},
    );
    expect(r, isNull);
  });

  test('вне допуска — null', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(const Offset(50, 50), tolerance: 1.0);
    expect(r, isNull);
  });

  test('отключённые типы не предлагаются', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final settings = SnapSettings(vertex: false);
    final r = engine.query(
      const Offset(9.9, 0.1),
      tolerance: 1.0,
      settings: settings,
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
  });

  test('отключённые привязки целиком — null', () {
    final engine = SnapEngine(_doc([
      DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
    ]));
    final r = engine.query(
      const Offset(9.9, 0.1),
      tolerance: 1.0,
      settings: SnapSettings(enabled: false),
    );
    expect(r, isNull);
  });

  test('касательная к окружности от точки', () {
    final engine = SnapEngine(_doc([
      DxfCircle(layer: '0', cx: 0, cy: 0, radius: 10),
    ]));
    final r = engine.query(
      const Offset(5, 8.66),
      tolerance: 0.5,
      from: const Offset(20, 0),
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.tangent);
    expect(r.point.dx, closeTo(5, 0.1));
    expect(r.point.dy, closeTo(8.66, 0.1));
  });

  test('касательная к дуге — только в пределах дуги', () {
    final engine = SnapEngine(_doc([
      DxfArc(layer: '0', cx: 0, cy: 0, radius: 10, startAngle: 0, endAngle: 90),
    ]));
    final onArc = engine.query(
      const Offset(5, 8.66),
      tolerance: 0.5,
      from: const Offset(20, 0),
    );
    expect(onArc, isNotNull);
    expect(onArc!.type, SnapType.tangent);

    final offArc = engine.query(
      const Offset(5, -8.66),
      tolerance: 0.5,
      from: const Offset(20, 0),
    );
    expect(offArc, isNull);
  });

  test('касательная изнутри окружности невозможна', () {
    final engine = SnapEngine(_doc([
      DxfCircle(layer: '0', cx: 0, cy: 0, radius: 10),
    ]));
    final r = engine.query(
      const Offset(5, 8.66),
      tolerance: 0.5,
      from: const Offset(0, 0),
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
  });

  test('касательная отключается настройкой', () {
    final engine = SnapEngine(_doc([
      DxfCircle(layer: '0', cx: 0, cy: 0, radius: 10),
    ]));
    final r = engine.query(
      const Offset(5, 8.66),
      tolerance: 0.5,
      from: const Offset(20, 0),
      settings: SnapSettings(tangent: false),
    );
    expect(r, isNotNull);
    expect(r!.type, SnapType.nearest);
  });

  test('TEXT: точка вставки — вершина, источник dxf', () {
    final engine = SnapEngine(_doc([
      DxfText(layer: '0', x: 42, y: 17, content: 'X', height: 2),
    ]));
    final r = engine.query(const Offset(42.2, 17.3), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.vertex);
    expect(r.point.dx, closeTo(42, 1e-6));
    expect(r.point.dy, closeTo(17, 1e-6));
    expect(r.source, SnapSource.dxf);
  });

  test('SOLID: углы и рёбра', () {
    final engine = SnapEngine(_doc([
      DxfSolid(layer: '0', points: const [
        DxfVertex(0, 0),
        DxfVertex(10, 0),
        DxfVertex(10, 5),
        DxfVertex(10, 5),
      ]),
    ]));
    final v = engine.query(const Offset(0.3, 0.2), tolerance: 1.0);
    expect(v, isNotNull);
    expect(v!.type, SnapType.vertex);
    final n = engine.query(const Offset(5, 0.4), tolerance: 1.0);
    expect(n, isNotNull);
    expect(n!.type, SnapType.nearest);
    expect(n.point.dy, closeTo(0, 1e-6));
  });

  test('XLINE: пересечение с отрезком', () {
    final engine = SnapEngine(_doc([
      DxfRay(layer: '0', x: 5, y: 5, dx: 1, dy: 0, isInfinite: true),
      DxfLine(layer: '0', x1: 20, y1: -10, x2: 20, y2: 10),
    ]));
    final r = engine.query(const Offset(20.3, 5.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(20, 1e-6));
    expect(r.point.dy, closeTo(5, 1e-6));
  });

  test('XLINE: база — вершина, nearest на прямой', () {
    final engine = SnapEngine(_doc([
      DxfRay(layer: '0', x: 5, y: 5, dx: 1, dy: 0, isInfinite: true),
    ]));
    final base = engine.query(const Offset(5.2, 5.2), tolerance: 1.0);
    expect(base, isNotNull);
    expect(base!.type, SnapType.vertex);
    final near = engine.query(const Offset(30, 5.4), tolerance: 1.0);
    expect(near, isNotNull);
    expect(near!.type, SnapType.nearest);
    expect(near.point.dx, closeTo(30, 1e-6));
    expect(near.point.dy, closeTo(5, 1e-6));
  });

  test('RAY: привязка только вперёд от базы', () {
    final engine = SnapEngine(_doc([
      DxfRay(layer: '0', x: 0, y: 0, dx: 1, dy: 0),
    ]));
    final r = engine.query(const Offset(-5, 0.2), tolerance: 1.0);
    expect(r, isNull);
  });

  test('XLINE скрытого слоя не привязывается', () {
    final engine = SnapEngine(_doc([
      DxfRay(layer: 'HID', x: 5, y: 5, dx: 1, dy: 0, isInfinite: true),
    ]));
    final r = engine.query(
      const Offset(30, 5.2),
      tolerance: 1.0,
      hiddenLayers: {'HID'},
    );
    expect(r, isNull);
  });

  test('смешанное пересечение: нарисованная прямая × линия чертежа', () {
    final engine = SnapEngine(
      _doc([
        DxfLine(layer: '0', x1: 20, y1: -10, x2: 20, y2: 10),
      ]),
      drawnObjects: [
        DrawnObject(
          id: 'r',
          drawingId: 'd',
          type: DrawnType.ray,
          points: const [Offset(5, 5), Offset(6, 5)],
          createdAt: DateTime(2026),
        ),
      ],
    );
    final r = engine.query(const Offset(20.2, 5.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(20, 1e-6));
    expect(r.point.dy, closeTo(5, 1e-6));
    expect(r.source, SnapSource.mixed);
  });

  test('смешанное пересечение: XLINE чертежа × нарисованный отрезок', () {
    final engine = SnapEngine(
      _doc([
        DxfRay(layer: '0', x: 5, y: 5, dx: 1, dy: 0, isInfinite: true),
      ]),
      drawnObjects: [
        DrawnObject(
          id: 'l',
          drawingId: 'd',
          type: DrawnType.line,
          points: const [Offset(20, -10), Offset(20, 10)],
          createdAt: DateTime(2026),
        ),
      ],
    );
    final r = engine.query(const Offset(20.2, 5.2), tolerance: 1.0);
    expect(r, isNotNull);
    expect(r!.type, SnapType.intersection);
    expect(r.point.dx, closeTo(20, 1e-6));
    expect(r.point.dy, closeTo(5, 1e-6));
    expect(r.source, SnapSource.mixed);
  });
}
