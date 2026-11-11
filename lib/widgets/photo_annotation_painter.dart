import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/photo_annotation.dart';

/// Рисует примитивы поверх фото. Координаты примитивов нормализованы,
/// поэтому painter работает и для превью, и для сохранения в полном размере
/// (достаточно передать [imageSize] и размер холста с тем же соотношением).
class PhotoAnnotationPainter extends CustomPainter {
  PhotoAnnotationPainter({required this.shapes, required this.imageSize});

  final List<PhotoShape> shapes;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = imageSize.width == 0 ? 1.0 : size.width / imageSize.width;
    Offset toCanvas(Offset o) => Offset(o.dx * size.width, o.dy * size.height);

    for (final shape in shapes) {
      if (!shape.hasGeometry) continue;
      final paint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, shape.strokeWidth * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      switch (shape.tool) {
        case PhotoTool.pencil:
          if (shape.points.length == 1) {
            canvas.drawCircle(toCanvas(shape.points.first),
                paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
            break;
          }
          final path = Path()
            ..moveTo(toCanvas(shape.points.first).dx,
                toCanvas(shape.points.first).dy);
          for (final point in shape.points.skip(1)) {
            final p = toCanvas(point);
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);
          break;
        case PhotoTool.line:
          canvas.drawLine(
              toCanvas(shape.points.first), toCanvas(shape.points.last), paint);
          break;
        case PhotoTool.rect:
          canvas.drawRect(
              Rect.fromPoints(
                  toCanvas(shape.points.first), toCanvas(shape.points.last)),
              paint);
          break;
        case PhotoTool.circle:
          final center = toCanvas(shape.points.first);
          final edge = toCanvas(shape.points.last);
          canvas.drawCircle(center, (edge - center).distance, paint);
          break;
        case PhotoTool.arrow:
          final from = toCanvas(shape.points.first);
          final to = toCanvas(shape.points.last);
          canvas.drawLine(from, to, paint);
          _drawArrowHead(canvas, from, to, paint);
          break;
        case PhotoTool.text:
          final text = shape.text?.trim() ?? '';
          if (text.isEmpty) break;
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: shape.color,
                fontSize: math.max(8.0, shape.textSize * scale),
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(
                      color: Colors.black45,
                      blurRadius: 2,
                      offset: Offset(1, 1)),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          painter.paint(canvas, toCanvas(shape.points.first));
          break;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final length = (to - from).distance;
    if (length < 1) return;
    final headSize = math.max(paint.strokeWidth * 3.5, length * 0.22);
    final direction = (to - from) / length;
    final normal = Offset(-direction.dy, direction.dx);
    final base = to - direction * headSize;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + normal.dx * headSize * 0.55,
          base.dy + normal.dy * headSize * 0.55)
      ..lineTo(base.dx - normal.dx * headSize * 0.55,
          base.dy - normal.dy * headSize * 0.55)
      ..close();
    canvas.drawPath(path, Paint()..color = paint.color);
  }

  @override
  bool shouldRepaint(covariant PhotoAnnotationPainter oldDelegate) =>
      oldDelegate.shapes != shapes || oldDelegate.imageSize != imageSize;
}
