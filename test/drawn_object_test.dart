import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/drawn_object.dart';

void main() {
  test('JSON round-trip всех типов объектов', () {
    for (final type in DrawnType.values) {
      final original = DrawnObject(
        id: 'id-${type.name}',
        drawingId: 'd1',
        type: type,
        points: const [Offset(1, 2), Offset(3, 4)],
        bulges: type == DrawnType.cloud ? const [1.0, 1.0] : const [],
        text: type == DrawnType.text ? 'Привет' : null,
        height: type == DrawnType.text ? 2.5 : null,
        color: 0xFFFF9800,
        strokePx: 3.0,
        rotation: type == DrawnType.text ? 27.5 : 0,
        layer: type == DrawnType.text ? 'Слой 2' : kDefaultDrawnLayer,
        createdAt: DateTime(2026, 10, 30, 12, 0),
      );
      final restored = DrawnObject.fromJson(original.toJson(), 'd1');
      expect(restored, isNotNull, reason: type.name);
      expect(restored!.type, type);
      expect(restored.points.length, 2);
      expect(restored.points.first, const Offset(1, 2));
      expect(restored.color, 0xFFFF9800);
      expect(restored.strokePx, 3.0);
      expect(restored.text, original.text);
      expect(restored.height, original.height);
      expect(restored.bulges, original.bulges);
      expect(restored.rotation, original.rotation);
      expect(restored.layer, original.layer);
      expect(restored.createdAt, original.createdAt);
    }
  });

  test('копия с изменённым положением и поворотом', () {
    final original = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(1, 2)],
      text: 'А',
      createdAt: DateTime(2026, 10, 30),
    );
    final moved = original.copyWith(
      points: const [Offset(5, 6)],
      rotation: 45,
    );
    expect(moved.id, original.id);
    expect(moved.points.first, const Offset(5, 6));
    expect(moved.rotation, 45);
    expect(moved.text, 'А');
    expect(original.points.first, const Offset(1, 2));
  });

  test('умолчания для данных без color/strokePx (старые версии)', () {
    final restored = DrawnObject.fromJson(
      {
        'id': 'x',
        'type': 'line',
        'points': [1, 2, 3, 4],
        'createdAt': '2026-10-30T10:00:00',
      },
      'd1',
    );
    expect(restored, isNotNull);
    expect(restored!.color, kDrawnDefaultColor);
    expect(restored.strokePx, kDrawnDefaultStrokePx);
    expect(restored.bulges, isEmpty);
    expect(restored.layer, kDefaultDrawnLayer);
    expect(restored.rotation, 0);
  });

  test('битые данные — null', () {
    expect(DrawnObject.fromJson({'type': 'line', 'points': []}, 'd1'), isNull);
    expect(
      DrawnObject.fromJson({
        'type': 'unknown',
        'points': [1, 2]
      }, 'd1'),
      isNull,
    );
  });

  test('точка с одной парой координат восстанавливается', () {
    final restored = DrawnObject.fromJson(
      {
        'id': 'p',
        'type': 'point',
        'points': [10, 20],
        'bulges': [],
        'color': 0xFFFFFFFF,
        'strokePx': 2.0,
        'createdAt': '2026-10-30T10:00:00',
      },
      'd1',
    );
    expect(restored, isNotNull);
    expect(restored!.points.single, const Offset(10, 20));
  });

  test('списки толщин и цветов — 5 и 8 вариантов', () {
    expect(kDrawnStrokeOptions.length, 5);
    expect(kDrawnColorOptions.length, 8);
    expect(kDrawnStrokeOptions.every((v) => v > 0), isTrue);
  });
}
