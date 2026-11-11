import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/measurement.dart';

void main() {
  PolygonMeasurement square({required bool closed}) => PolygonMeasurement(
        id: '1',
        drawingId: 'd',
        createdAt: DateTime(2026),
        points: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
        closed: closed,
      );

  test('замкнутый контур: периметр и площадь', () {
    final m = square(closed: true);
    expect(m.getPathLength(), closeTo(30, 1e-9));
    expect(m.getPerimeter(), closeTo(40, 1e-9));
    expect(m.getArea(), closeTo(100, 1e-9));

    final text = m.formatResult('m');
    expect(text, contains('Периметр'));
    expect(text, contains('Площадь'));
  });

  test('открытый контур: только длина, без площади/периметра', () {
    final m = square(closed: false);
    expect(m.getPathLength(), closeTo(30, 1e-9));
    expect(m.getPerimeter(), closeTo(30, 1e-9));

    final text = m.formatResult('m');
    expect(text, contains('Длина'));
    expect(text, isNot(contains('Площадь')));
    expect(text, isNot(contains('Периметр')));
  });

  test('расстояние 3-4-5', () {
    final m = DistanceMeasurement(
      id: '1',
      drawingId: 'd',
      createdAt: DateTime(2026),
      point1: const Offset(0, 0),
      point2: const Offset(3, 4),
    );
    expect(m.getValueInDrawingUnits(), closeTo(5, 1e-9));
    expect(m.formatResult('m'), contains('5.000'));
  });

  test('форматирование единиц длины и площади', () {
    expect(formatLength(1.0, 'mm'), contains('мм'));
    expect(formatLength(1.0, 'cm'), contains('см'));
    expect(formatLength(1.0, 'm'), contains('м'));
    expect(formatArea(1.0, 'm'), contains('м²'));
    expect(formatArea(1.0, 'cm'), contains('см²'));
  });
}
