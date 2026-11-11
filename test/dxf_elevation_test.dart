import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/services/dxf_elevation.dart';

DxfDocument _doc(List<DxfEntity> entities) => DxfDocument(
      layers: [DxfLayer(name: '0')],
      entities: entities,
      minX: 0,
      minY: 0,
      maxX: 30,
      maxY: 30,
    );

void main() {
  group('elevationAtPoint (H из самого объекта)', () {
    test('линия: отметка из группы 30', () {
      final doc = _doc([
        DxfLine(layer: '0', elevation: 2.5, x1: 0, y1: 0, x2: 10, y2: 0),
      ]);
      expect(elevationAtPoint(doc, const Offset(5, 0)), 2.5);
    });

    test('окружность: отметка центра', () {
      final doc = _doc([
        DxfCircle(layer: '0', elevation: -1.25, cx: 5, cy: 20, radius: 3),
      ]);
      // точка на окружности (r = 3)
      expect(elevationAtPoint(doc, const Offset(8, 20)), -1.25);
    });

    test('полилиния: отметка (38) на любой стороне', () {
      final doc = _doc([
        DxfLwPolyline(
          layer: '0',
          elevation: 7.0,
          vertices: const [
            DxfVertex(0, 10),
            DxfVertex(10, 10),
            DxfVertex(10, 20),
          ],
        ),
      ]);
      expect(elevationAtPoint(doc, const Offset(5, 10)), 7.0);
      expect(elevationAtPoint(doc, const Offset(10, 15)), 7.0);
    });

    test('слой скрыт — высота не берётся', () {
      final doc = _doc([
        DxfLine(layer: 'HIDE', elevation: 4.0, x1: 0, y1: 5, x2: 10, y2: 5),
      ]);
      expect(elevationAtPoint(doc, const Offset(5, 5)), 4.0);
      expect(
        elevationAtPoint(doc, const Offset(5, 5), hiddenLayers: {'HIDE'}),
        isNull,
      );
    });

    test('пустое место — null', () {
      final doc = _doc([
        DxfLine(layer: '0', elevation: 1.0, x1: 0, y1: 0, x2: 10, y2: 0),
      ]);
      expect(elevationAtPoint(doc, const Offset(5, 25)), isNull);
    });

    test('по умолчанию отметка 0', () {
      final doc = _doc([
        DxfPoint(layer: '0', x: 3, y: 3),
      ]);
      expect(elevationAtPoint(doc, const Offset(3, 3)), 0.0);
    });
  });
}
