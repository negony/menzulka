import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

import '../utils/dxf_overlays.dart';

/// Точки DXF рисуются в экранном пространстве: постоянный размер,
/// не пропадают и не теряют точность на сильном зуме.
class DxfPointPainter extends CustomPainter {
  final DxfOverlays overlays;
  final Matrix4 matrix;
  final double minX, maxY;

  /// Скрытые слои DXF.
  final Set<String> hiddenLayers;

  DxfPointPainter({
    required this.overlays,
    required this.matrix,
    required this.minX,
    required this.maxY,
    this.hiddenLayers = const {},
  });

  static const double _haloR = 5.5;
  static const double _dotR = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in overlays.points) {
      if (hiddenLayers.contains(p.layer)) continue;
      final v = matrix.transform3(vec.Vector3(p.x - minX, maxY - p.y, 0));
      final s = Offset(v.x, v.y);
      if (s.dx < -_haloR ||
          s.dy < -_haloR ||
          s.dx > size.width + _haloR ||
          s.dy > size.height + _haloR) {
        continue;
      }
      final halo = p.color.computeLuminance() > 0.5
          ? const Color(0xFF212830)
          : Colors.white;
      canvas.drawCircle(s, _haloR, Paint()..color = halo);
      canvas.drawCircle(s, _dotR, Paint()..color = p.color);
    }
  }

  @override
  bool shouldRepaint(covariant DxfPointPainter old) => true;
}

/// Текст DXF рисуется в экранном пространстве при текущем масштабе —
/// глифы растеризуются нужным размером и не «пикселят» при приближении.
class DxfTextPainter extends CustomPainter {
  final DxfOverlays overlays;
  final Matrix4 matrix;
  final double minX, maxY;

  /// Скрытые слои DXF.
  final Set<String> hiddenLayers;

  DxfTextPainter({
    required this.overlays,
    required this.matrix,
    required this.minX,
    required this.maxY,
    this.hiddenLayers = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = matrix.getMaxScaleOnAxis();
    // Прямоугольники уже нарисованных подписей — перекрывающиеся пропускаем,
    // чтобы на общем виде была читаемая выборка, а не сплошное нагромождение.
    final drawn = <Rect>[];
    for (final t in overlays.texts) {
      if (hiddenLayers.contains(t.layer)) continue;
      final v = matrix.transform3(vec.Vector3(t.x - minX, maxY - t.y, 0));
      final s = Offset(v.x, v.y);
      if (s.dx < -300 ||
          s.dy < -300 ||
          s.dx > size.width + 300 ||
          s.dy > size.height + 300) {
        continue;
      }
      // Держим читаемый размер в диапазоне 6..28 px независимо от масштаба:
      // на общем виде подписи видны, при сильном зуме не «взрываются».
      final rawFontSize = t.height * scale;
      final fontSize = rawFontSize.clamp(6.0, 28.0);
      final tp = TextPainter(
        text: TextSpan(
          text: t.content,
          style: TextStyle(color: t.color, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final baseline =
          tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final rect = Rect.fromLTWH(s.dx, s.dy - baseline, tp.width, tp.height);
      var overlaps = false;
      for (final r in drawn) {
        if (r.overlaps(rect.inflate(2))) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) {
        tp.dispose();
        continue;
      }
      drawn.add(rect);
      canvas.save();
      canvas.translate(s.dx, s.dy);
      if (t.rotation != 0) {
        canvas.rotate(-t.rotation * math.pi / 180);
      }
      tp.paint(canvas, Offset(0, -baseline));
      canvas.restore();
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant DxfTextPainter old) => true;
}
