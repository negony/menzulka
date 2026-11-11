import 'package:flutter/material.dart';

/// Иконка «Объектная привязка» в стиле AutoCAD 2024: квадрат-апертура
/// с маркером (точкой привязки) в верхнем левом углу.
class OsnapIcon extends StatelessWidget {
  final double size;
  final bool enabled;

  const OsnapIcon({super.key, this.size = 22, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final outline = enabled ? const Color(0xFF37474F) : Colors.grey;
    final marker = enabled ? const Color(0xFFFF9800) : Colors.grey;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OsnapPainter(outline, marker)),
    );
  }
}

class _OsnapPainter extends CustomPainter {
  final Color outline;
  final Color marker;

  _OsnapPainter(this.outline, this.marker);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeJoin = StrokeJoin.miter;

    // Апертура-квадрат.
    canvas.drawRect(
      Rect.fromLTWH(s * 0.32, s * 0.32, s * 0.58, s * 0.58),
      stroke,
    );

    // Маркер привязки — оранжевый квадратик, «накрывающий» верхний левый угол.
    final markerRect = Rect.fromLTWH(s * 0.08, s * 0.08, s * 0.34, s * 0.34);
    canvas.drawRect(markerRect, Paint()..color = marker);

    // Тёмная точка в центре маркера.
    final dot = Rect.fromLTWH(s * 0.19, s * 0.19, s * 0.12, s * 0.12);
    canvas.drawRect(dot, Paint()..color = const Color(0xFF212830));
  }

  @override
  bool shouldRepaint(covariant _OsnapPainter old) =>
      old.outline != outline || old.marker != marker;
}
