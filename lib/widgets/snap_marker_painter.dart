import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

import '../models/snap_models.dart';
import 'snap_glyph.dart';

/// Экранный маркер привязки (постоянный размер) + подсказка в стиле AutoSnap.
class SnapMarkerPainter extends CustomPainter {
  final SnapResult result;
  final Matrix4 matrix;
  final double minX, maxY;
  final double glyphSize;

  SnapMarkerPainter({
    required this.result,
    required this.matrix,
    required this.minX,
    required this.maxY,
    this.glyphSize = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final v = matrix.transform3(vec.Vector3(
      result.point.dx - minX,
      maxY - result.point.dy,
      0,
    ));
    final s = Offset(v.x, v.y);
    if (s.dx < -60 ||
        s.dy < -60 ||
        s.dx > size.width + 60 ||
        s.dy > size.height + 60) {
      return;
    }

    drawSnapGlyph(canvas, s, result.type, size: glyphSize);

    final tp = TextPainter(
      text: TextSpan(
        text: result.type.label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padX = 6.0;
    const padY = 3.0;
    final boxW = tp.width + padX * 2;
    final boxH = tp.height + padY * 2;
    var left = s.dx + glyphSize * 0.8;
    var top = s.dy - glyphSize * 0.8 - boxH;
    left = left.clamp(4.0, size.width - boxW - 4);
    if (top < 4) top = s.dy + glyphSize * 0.8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxW, boxH),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFFFFF9C4).withValues(alpha: 0.98),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFBDB27A),
    );
    tp.paint(canvas, Offset(left + padX, top + padY));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant SnapMarkerPainter old) =>
      old.result != result ||
      old.matrix != matrix ||
      old.minX != minX ||
      old.maxY != maxY ||
      old.glyphSize != glyphSize;
}
