import 'package:flutter/material.dart';

import '../models/measurement.dart';

/// Подписи длин сторон измерения в **экранных** координатах.
///
/// Раньше подписи рисовались внутри масштабируемого холста с размером шрифта
/// `12 / scale`: при сильном зуме шрифт вырождался (расплывался и исчезал).
/// Теперь текст рисуется поверх чертежа фиксированного размера, а положение
/// берётся из текущей матрицы «локальные координаты → экран».
class MeasurementLabelsPainter extends CustomPainter {
  /// Вершины измерения в локальных координатах чертежа.
  final List<Offset> points;

  /// Матрица InteractiveViewer (локальные координаты → экран).
  final Matrix4 matrix;

  final String units;
  final bool closed;

  MeasurementLabelsPainter({
    required this.points,
    required this.matrix,
    this.units = 'm',
    this.closed = false,
  });

  static const double _labelPx = 12.0;
  static const double _offsetPx = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final screen =
        points.map((p) => MatrixUtils.transformPoint(matrix, p)).toList();
    final isClosed = closed && points.length >= 3;

    for (var i = 0; i < screen.length - 1; i++) {
      _drawLabel(
        canvas,
        screen[i],
        screen[i + 1],
        formatLength((points[i + 1] - points[i]).distance, units),
      );
    }
    if (isClosed) {
      _drawLabel(
        canvas,
        screen.last,
        screen.first,
        formatLength((points.first - points.last).distance, units),
      );
    }
  }

  void _drawLabel(Canvas canvas, Offset a, Offset b, String text) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final d = b - a;
    final len = d.distance;
    final normal =
        len <= 0 ? const Offset(0, -1) : Offset(-d.dy / len, d.dx / len);
    // Смещение подписи в «верхнюю» сторону от линии.
    final sign = normal.dy > 0 ? -1.0 : 1.0;
    final pos = mid + normal * (_offsetPx * sign);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: _labelPx,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: pos,
      width: tp.width + 16,
      height: tp.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant MeasurementLabelsPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.matrix != matrix ||
        oldDelegate.units != units ||
        oldDelegate.closed != closed;
  }
}
