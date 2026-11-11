import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import 'aci_colors.dart';
import 'dxf_affine.dart';

/// Цвет сущности с учётом true color / ACI / BYLAYER / BYBLOCK.
Color resolveDxfColor(
    DxfEntity e, Map<String, DxfLayer> layers, Color? blockColor) {
  if (e.trueColor != null) return trueColorToColor(e.trueColor!);
  final ci = e.colorIndex;
  if (ci != null) {
    if (ci == 0) return blockColor ?? aciToColor(7); // BYBLOCK
    if (ci >= 1 && ci <= 255) return aciToColor(ci);
  }
  final layer = layers[e.layer];
  if (layer != null) {
    if (layer.trueColor != null) return trueColorToColor(layer.trueColor!);
    return aciToColor(layer.colorIndex);
  }
  return aciToColor(7);
}

/// Вес линии (1/100 мм) с учётом BYLAYER/BYBLOCK/DEFAULT.
int resolveDxfLineWeight(
    DxfEntity e, Map<String, DxfLayer> layers, int? blockLw) {
  final lw = e.lineWeight;
  if (lw == null || lw == -1) return layers[e.layer]?.lineWeight ?? 25;
  if (lw == -2) return blockLw ?? 25;
  if (lw == -3) return 25;
  return lw <= 0 ? 25 : lw;
}

/// Перевод веса линии (1/100 мм) в пиксели экрана.
double lineWeightToPx(int lw) {
  if (lw <= 0) return 1.6;
  return (lw * 0.064).clamp(1.0, 25.0);
}

/// Точка DXF, приведённая к мировым координатам (с раскрытием блоков).
class DxfFlatPoint {
  final double x, y;
  final Color color;

  /// Эффективный слой (для скрытия слоёв).
  final String layer;
  const DxfFlatPoint(this.x, this.y, this.color, this.layer);
}

/// Текст DXF, приведённый к мировым координатам (с раскрытием блоков).
class DxfFlatText {
  final double x, y;
  final String content;
  final double height;
  final double rotation;
  final Color color;

  /// Эффективный слой (для скрытия слоёв).
  final String layer;
  const DxfFlatText(this.x, this.y, this.content, this.height, this.rotation,
      this.color, this.layer);
}

class DxfOverlays {
  final List<DxfFlatPoint> points;
  final List<DxfFlatText> texts;
  const DxfOverlays(this.points, this.texts);
  static const empty = DxfOverlays([], []);
}

/// Раскрывает блоки и собирает точки/тексты в мировых координатах.
/// Они рисуются в экранном пространстве — так текст не пикселит,
/// а точки не пропадают при сильном зуме.
DxfOverlays buildDxfOverlays(DxfDocument document) {
  final layers = {for (final l in document.layers) l.name: l};
  final points = <DxfFlatPoint>[];
  final texts = <DxfFlatText>[];

  void walk(DxfEntity e, DxfAffine xf, Color? blockColor, int depth,
      {String? inheritLayer}) {
    if (e is DxfInsert) {
      final block = document.blocks[e.blockName];
      if (block == null || depth > 8) return;
      final child = xf.mul(insertAffine(e, block));
      final insertColor = resolveDxfColor(e, layers, blockColor);
      for (final be in block.entities) {
        walk(be, child, insertColor, depth + 1, inheritLayer: e.layer);
      }
      return;
    }
    // Эффективный слой: объект на слое 0 внутри блока — на слое вставки.
    String effectiveLayer(DxfEntity entity) =>
        (entity.layer == '0' && inheritLayer != null)
            ? inheritLayer
            : entity.layer;
    if (e is DxfPoint) {
      final w = xf.apply(e.x, e.y);
      points.add(DxfFlatPoint(
          w.x, w.y, resolveDxfColor(e, layers, blockColor), effectiveLayer(e)));
    } else if (e is DxfText) {
      if (e.content.isEmpty) return;
      final w = xf.apply(e.x, e.y);
      final s = xf.uniformScale;
      texts.add(DxfFlatText(
        w.x,
        w.y,
        e.content,
        e.height * s,
        e.rotation + xf.rotationDeg,
        resolveDxfColor(e, layers, blockColor),
        effectiveLayer(e),
      ));
    }
  }

  for (final e in document.entities) {
    walk(e, DxfAffine.identity, null, 0);
  }
  return DxfOverlays(points, texts);
}
