import 'package:flutter/material.dart';

/// Иконки режимов черчения в стиле AutoCAD, перерисованные в стиле приложения
/// (как OsnapIcon/SnapGlyph: тонкий штрих + акцентная заливка).
///
/// Орто: прямой угол с двумя осями и стрелками (как кнопка «ОРТО» в AutoCAD).
class OrthoIcon extends StatelessWidget {
  final double size;
  final bool enabled;

  const OrthoIcon({super.key, this.size = 22, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OrthoPainter(enabled)),
    );
  }
}

class _OrthoPainter extends CustomPainter {
  final bool enabled;
  _OrthoPainter(this.enabled);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final color = enabled ? Colors.blue : Colors.grey;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    // Уголок: вертикаль + горизонталь от общего угла.
    final corner = Offset(s * 0.28, s * 0.28);
    canvas.drawLine(corner, Offset(corner.dx, s * 0.86), stroke);
    canvas.drawLine(corner, Offset(s * 0.86, corner.dy), stroke);

    // Стрелки на концах осей (как у орто-режима).
    final arrow = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final a = s * 0.14;
    // Вниз.
    final p1 = Offset(corner.dx, s * 0.9);
    canvas.drawPath(
      Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p1.dx - a, p1.dy - a)
        ..lineTo(p1.dx + a, p1.dy - a)
        ..close(),
      arrow,
    );
    // Вправо.
    final p2 = Offset(s * 0.92, corner.dy);
    canvas.drawPath(
      Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p2.dx - a, p2.dy - a)
        ..lineTo(p2.dx - a, p2.dy + a)
        ..close(),
      arrow,
    );

    // Маркер угла.
    canvas.drawRect(
      Rect.fromLTWH(
          corner.dx - s * 0.06, corner.dy - s * 0.06, s * 0.12, s * 0.12),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _OrthoPainter old) => old.enabled != enabled;
}

/// Угловая привязка (полярный режим): два луча под углом + дуга со стрелкой
/// (как кнопка «ПОЛЯР» в AutoCAD).
class PolarIcon extends StatelessWidget {
  final double size;
  final bool enabled;

  const PolarIcon({super.key, this.size = 22, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PolarPainter(enabled)),
    );
  }
}

class _PolarPainter extends CustomPainter {
  final bool enabled;
  _PolarPainter(this.enabled);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final color = enabled ? Colors.blue : Colors.grey;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round;

    final vertex = Offset(s * 0.16, s * 0.84);
    final horizontal = Offset(s * 0.92, s * 0.84);
    const angle = -0.6; // ~34° вверх
    final rayLen = s * 0.78;
    final slanted = Offset(
      vertex.dx + rayLen * 0.86,
      vertex.dy + rayLen * angle,
    );

    canvas.drawLine(vertex, horizontal, stroke);
    canvas.drawLine(vertex, slanted, stroke);

    // Дуга между лучами.
    final radius = s * 0.34;
    const start = 0.0;
    const sweep = angle; // отрицательный — против часовой (вверх)
    final arcRect = Rect.fromCircle(center: vertex, radius: radius);
    canvas.drawArc(arcRect, start, sweep, false, stroke);

    // Стрелка на дуге.
    final tip = Offset(
      vertex.dx + radius * 0.86,
      vertex.dy + radius * angle,
    );
    final tangent = const Offset(-angle, 1) * (s * 0.1);
    final arrow = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + tangent.dx, tip.dy + tangent.dy)
        ..lineTo(
            tip.dx - tangent.dy * 0.9 - s * 0.06, tip.dy + tangent.dx * 0.9)
        ..lineTo(
            tip.dx + tangent.dy * 0.9 - s * 0.06, tip.dy - tangent.dx * 0.9)
        ..close(),
      arrow,
    );

    // Маркер вершины (как у объектной привязки).
    canvas.drawRect(
      Rect.fromLTWH(
          vertex.dx - s * 0.07, vertex.dy - s * 0.07, s * 0.14, s * 0.14),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PolarPainter old) => old.enabled != enabled;
}
