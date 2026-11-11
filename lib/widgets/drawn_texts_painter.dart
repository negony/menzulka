import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

import '../models/drawn_object.dart';
import '../models/measurement.dart';
import '../utils/drawn_geometry.dart';

/// Тексты нарисованных объектов в экранных координатах:
/// инструмент «текст» (с поворотом) и подпись размера (вдоль размерной линии).
class DrawnTextsPainter extends CustomPainter {
  final List<DrawnObject> objects;

  /// Матрица «локальные координаты -> экран».
  final Matrix4 matrix;
  final double minX, maxY;
  final String units;

  /// Масштаб «мир -> экран» (для размера шрифта).
  final double scale;

  /// Выбранный для редактирования текст (рамка выделения).
  final String? selectedId;

  /// «Живая» копия объекта при перемещении/повороте.
  final DrawnObject? edited;

  DrawnTextsPainter({
    required this.objects,
    required this.matrix,
    required this.minX,
    required this.maxY,
    required this.units,
    required this.scale,
    this.selectedId,
    this.edited,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale <= 0 ? 1.0 : scale;
    // Для старых объектов без высоты — 12 px в текущем масштабе.
    final fallbackHeight = 12 / s;
    for (var object in objects) {
      if (edited != null && edited!.id == object.id) {
        object = edited!;
      }
      if (object.type == DrawnType.text) {
        final text = object.text;
        if (text == null || text.isEmpty || object.points.isEmpty) continue;
        _drawText(
          canvas,
          size,
          world: object.points.first,
          text: text,
          angleDeg: object.rotation,
          heightWorld: object.height ?? fallbackHeight,
          color: Color(object.color),
          withBackdrop: false,
          selected: object.id == selectedId,
        );
      } else if (object.type == DrawnType.dimension) {
        if (object.points.length < 3) continue;
        final layout = layoutDimension(
          object.points[0],
          object.points[1],
          object.points[2],
          textHeight: object.height ?? fallbackHeight,
        );
        if (layout == null) continue;
        _drawText(
          canvas,
          size,
          world: layout.textPosition,
          text: formatLength(layout.length, units),
          angleDeg: layout.textAngleDeg,
          heightWorld: object.height ?? fallbackHeight,
          color: Color(object.color),
          withBackdrop: true,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    Size size, {
    required Offset world,
    required String text,
    required double angleDeg,
    required double heightWorld,
    required Color color,
    required bool withBackdrop,
    bool selected = false,
  }) {
    final v =
        matrix.transform3(vec.Vector3(world.dx - minX, maxY - world.dy, 0));
    final screen = Offset(v.x, v.y);
    if (screen.dx < -300 ||
        screen.dy < -300 ||
        screen.dx > size.width + 300 ||
        screen.dy > size.height + 300) {
      return;
    }
    final s = scale <= 0 ? 1.0 : scale;
    // Верхнего предела нет: текст масштабируется щипком без ограничений.
    final fontSize = (heightWorld * s).clamp(2.0, 4000.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(screen.dx, screen.dy);
    if (angleDeg != 0) {
      canvas.rotate(-angleDeg * math.pi / 180);
    }
    if (withBackdrop) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 10,
        height: tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = Colors.black.withValues(alpha: 0.65),
      );
    }
    if (selected) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 16,
        height: tp.height + 12,
      );
      final border = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        border,
      );
      // Уголки-маркеры.
      final dot = Paint()..color = Colors.cyanAccent;
      for (final c in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        canvas.drawCircle(c, 2.6, dot);
      }
    }
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant DrawnTextsPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.matrix != matrix ||
        oldDelegate.minX != minX ||
        oldDelegate.maxY != maxY ||
        oldDelegate.units != units ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.edited != edited;
  }
}
