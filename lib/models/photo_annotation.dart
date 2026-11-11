import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Инструменты рисования поверх фотографии.
enum PhotoTool { pencil, line, rect, circle, arrow, text }

/// Примитив, нарисованный поверх фото.
///
/// Точки хранятся в нормализованных координатах (0..1) относительно исходного
/// изображения, поэтому рисунок одинаково рисуется и в просмотрщике, и при
/// сохранении в полном разрешении. Толщина и размер текста — в пикселях
/// исходного изображения.
@immutable
class PhotoShape {
  const PhotoShape({
    required this.tool,
    required this.points,
    required this.color,
    this.strokeWidth = 5,
    this.text,
    this.textSize = 44,
  });

  final PhotoTool tool;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String? text;
  final double textSize;

  PhotoShape copyWith({List<Offset>? points, String? text}) => PhotoShape(
        tool: tool,
        points: points ?? this.points,
        color: color,
        strokeWidth: strokeWidth,
        text: text ?? this.text,
        textSize: textSize,
      );

  /// Есть ли у примитива достаточная геометрия для отрисовки.
  bool get hasGeometry {
    if (tool == PhotoTool.text) return (text?.trim().isNotEmpty ?? false);
    return points.length >= 2;
  }

  /// Габариты текста в пикселях изображения (для попадания пальцем).
  Rect? textBoundsPx(Size imageSize) {
    if (tool != PhotoTool.text || points.isEmpty) return null;
    final pos = Offset(
      points.first.dx * imageSize.width,
      points.first.dy * imageSize.height,
    );
    final chars = (text ?? '').runes.length;
    final width = math.max(textSize * 0.6, textSize * 0.62 * chars);
    final height = textSize * 1.25;
    return Rect.fromLTWH(pos.dx, pos.dy, width, height);
  }

  /// Попадает ли точка (нормализованная) в примитив с допуском [tolerancePx].
  bool hitTest(Offset normalized, Size imageSize, {double tolerancePx = 20}) {
    if (imageSize.isEmpty) return false;
    final p = Offset(
      normalized.dx * imageSize.width,
      normalized.dy * imageSize.height,
    );
    Offset toPx(Offset o) =>
        Offset(o.dx * imageSize.width, o.dy * imageSize.height);

    switch (tool) {
      case PhotoTool.pencil:
        if (points.isEmpty) return false;
        final pts = points.map(toPx).toList();
        if (pts.length == 1) return (p - pts.first).distance <= tolerancePx;
        for (var i = 0; i + 1 < pts.length; i++) {
          if (_distanceToSegment(p, pts[i], pts[i + 1]) <= tolerancePx) {
            return true;
          }
        }
        return false;
      case PhotoTool.line:
      case PhotoTool.arrow:
        if (points.length < 2) return false;
        return _distanceToSegment(p, toPx(points.first), toPx(points.last)) <=
            tolerancePx;
      case PhotoTool.rect:
        if (points.length < 2) return false;
        final r = Rect.fromPoints(toPx(points.first), toPx(points.last));
        final tol = tolerancePx;
        final nearVertical =
            (p.dx - r.left).abs() <= tol || (p.dx - r.right).abs() <= tol;
        final nearHorizontal =
            (p.dy - r.top).abs() <= tol || (p.dy - r.bottom).abs() <= tol;
        return (nearVertical &&
                p.dy >= r.top - tol &&
                p.dy <= r.bottom + tol) ||
            (nearHorizontal && p.dx >= r.left - tol && p.dx <= r.right + tol);
      case PhotoTool.circle:
        if (points.length < 2) return false;
        final c = toPx(points.first);
        final radius = (toPx(points.last) - c).distance;
        return ((p - c).distance - radius).abs() <= tolerancePx;
      case PhotoTool.text:
        final bounds = textBoundsPx(imageSize);
        return bounds != null && bounds.inflate(tolerancePx).contains(p);
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}

/// Результат редактирования фото.
class PhotoEditResult {
  const PhotoEditResult.added(this.path) : replaced = false;
  const PhotoEditResult.replaced(this.path) : replaced = true;

  /// Путь к файлу: исходный при замене, новый — при сохранении копии.
  final String path;
  final bool replaced;
}
