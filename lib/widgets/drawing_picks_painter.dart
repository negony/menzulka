import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

/// Маркеры точек, уже указанных в текущем инструменте рисования
/// (пока объект не завершён). Координаты — мировые.
class DrawingPicksPainter extends CustomPainter {
  final List<Offset> points;
  final Matrix4 matrix;
  final double minX, maxY;
  final Color color;

  DrawingPicksPainter({
    required this.points,
    required this.matrix,
    required this.minX,
    required this.maxY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final p in points) {
      final v = matrix.transform3(vec.Vector3(p.dx - minX, maxY - p.dy, 0));
      final s = Offset(v.x, v.y);
      if (s.dx < -10 ||
          s.dy < -10 ||
          s.dx > size.width + 10 ||
          s.dy > size.height + 10) {
        continue;
      }
      canvas.drawCircle(s, 3.0, paint);
      canvas.drawLine(s - const Offset(6, 0), s + const Offset(6, 0), paint);
      canvas.drawLine(s - const Offset(0, 6), s + const Offset(0, 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPicksPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.matrix != matrix ||
        oldDelegate.minX != minX ||
        oldDelegate.maxY != maxY ||
        oldDelegate.color != color;
  }
}
