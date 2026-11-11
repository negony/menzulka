import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/photo_annotation.dart';

void main() {
  const imageSize = Size(1000, 800);

  PhotoShape shape(PhotoTool tool, List<Offset> points,
          {String? text, Color color = Colors.red}) =>
      PhotoShape(tool: tool, points: points, color: color, text: text);

  group('PhotoShape.hitTest', () {
    test('линия: попадание рядом и промах', () {
      final line =
          shape(PhotoTool.line, const [Offset(0.1, 0.5), Offset(0.9, 0.5)]);
      expect(line.hitTest(const Offset(0.5, 0.505), imageSize), isTrue);
      expect(line.hitTest(const Offset(0.5, 0.7), imageSize), isFalse);
    });

    test('прямоугольник: попадание по рамке, не по центру', () {
      final rect =
          shape(PhotoTool.rect, const [Offset(0.2, 0.2), Offset(0.8, 0.7)]);
      expect(rect.hitTest(const Offset(0.2, 0.45), imageSize), isTrue);
      expect(rect.hitTest(const Offset(0.5, 0.45), imageSize), isFalse);
    });

    test('круг: попадание по кольцу', () {
      final circle =
          shape(PhotoTool.circle, const [Offset(0.5, 0.5), Offset(0.7, 0.5)]);
      // точка ровно на окружности (радиус 200 px от центра (500, 400))
      expect(circle.hitTest(const Offset(0.7, 0.5), imageSize), isTrue);
      expect(circle.hitTest(const Offset(0.5, 0.9), imageSize), isFalse);
    });

    test('карандаш: попадание по любой точке штриха', () {
      final pencil = shape(PhotoTool.pencil, const [
        Offset(0.1, 0.1),
        Offset(0.3, 0.3),
        Offset(0.5, 0.1),
      ]);
      expect(pencil.hitTest(const Offset(0.3, 0.3), imageSize), isTrue);
      expect(pencil.hitTest(const Offset(0.3, 0.8), imageSize), isFalse);
    });

    test('текст: попадание по габаритам', () {
      final text = shape(PhotoTool.text, const [Offset(0.1, 0.1)], text: 'ЛЮК');
      expect(text.hitTest(const Offset(0.12, 0.12), imageSize), isTrue);
      expect(text.hitTest(const Offset(0.9, 0.9), imageSize), isFalse);
    });

    test('текст: габариты не пустые', () {
      final text = shape(PhotoTool.text, const [Offset(0.1, 0.1)], text: 'ЛЮК');
      final bounds = text.textBoundsPx(imageSize);
      expect(bounds, isNotNull);
      expect(bounds!.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('пустой примитив не считается нарисованным', () {
      expect(
          shape(PhotoTool.line, const [Offset(0.1, 0.1)]).hasGeometry, isFalse);
      expect(
          shape(PhotoTool.text, const [Offset(0.1, 0.1)], text: '   ')
              .hasGeometry,
          isFalse);
      expect(
          shape(PhotoTool.text, const [Offset(0.1, 0.1)], text: 'ЛЮК')
              .hasGeometry,
          isTrue);
    });
  });

  group('PhotoEditResult', () {
    test('флаги замены и копии', () {
      const replaced = PhotoEditResult.replaced('/tmp/a.png');
      const added = PhotoEditResult.added('/tmp/b.png');
      expect(replaced.replaced, isTrue);
      expect(added.replaced, isFalse);
      expect(replaced.path, '/tmp/a.png');
      expect(added.path, '/tmp/b.png');
    });
  });
}
