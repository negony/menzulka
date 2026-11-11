import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Линии, точки и маркеры измерения (внутри масштабируемого холста).
///
/// Подписи длин рисуются отдельно в экранных координатах
/// ([MeasurementLabelsPainter]), чтобы не мылиться и не исчезать при зуме.
class MeasurementPainter extends CustomPainter {
  final List<Offset> points;

  /// Текущий масштаб «мир -> экран», чтобы точки и линии
  /// оставались постоянного размера в пикселях при любом зуме.
  final double scale;

  /// Контур замкнут — рисуем замыкающую сторону и маркер.
  final bool closed;

  /// Превью-точка под курсором (локальные координаты): пунктир от последней
  /// вершины и полый маркер — «резиновая нить» измерения.
  final Offset? previewPoint;

  MeasurementPainter({
    required this.points,
    required this.scale,
    this.closed = false,
    this.previewPoint,
  });

  static const double _dotPx = 5.0;
  static const double _strokePx = 2.0;
  static const double _ringPx = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final s = scale <= 0 ? 1.0 : scale;
    final pointRadius = _dotPx / s;
    final strokeWidth = _strokePx / s;
    final isClosed = closed && points.length >= 3;

    final linePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Стороны ломаной.
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    // Замыкающая сторона — визуальный признак замкнутого контура.
    if (isClosed) {
      final closingPaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points.last, points.first, closingPaint);
    }

    // «Резиновая нить» до текущей позиции курсора/привязки.
    final preview = previewPoint;
    if (preview != null) {
      final previewPaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, points.last, preview, previewPaint, 6 / s, 4 / s);
      canvas.drawCircle(
        preview,
        5 / s,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }

    // Точки.
    final pointPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, pointRadius, pointPaint);
    }

    // Маркер: замкнуто — «мишень» у первой точки; открыто — полое кольцо
    // у последней точки.
    if (isClosed) {
      canvas.drawCircle(
        points.first,
        _ringPx / s,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        points.first,
        _ringPx / s,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    } else if (points.length >= 2) {
      canvas.drawCircle(
        points.last,
        _ringPx / s,
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
    double gap,
  ) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = math.min(t + dash, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
    }
  }

  @override
  bool shouldRepaint(covariant MeasurementPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scale != scale ||
        oldDelegate.closed != closed ||
        oldDelegate.previewPoint != previewPoint;
  }
}
