import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import '../utils/layer_cache.dart';

class DxfCanvasPainter extends CustomPainter {
  final DxfDocument document;
  final Set<String> hiddenLayers;
  final DxfLayerCacheManager cacheManager;

  /// Текущий масштаб «мир -> экран»: нужен, чтобы толщина линий была
  /// постоянной в пикселях и не «исчезала» при уменьшении.
  final double scale;

  DxfCanvasPainter({
    required this.document,
    required this.hiddenLayers,
    required this.cacheManager,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Обходим все кэши: в DXF сущности могут быть на слоях, которых нет
    // в таблице LAYER (частая ситуация в чужих чертежах).
    for (final layerName in cacheManager.layerNames) {
      if (hiddenLayers.contains(layerName)) continue;
      final cache = cacheManager.getLayerCache(layerName);
      if (cache == null) continue;
      final picture = cache.getPicture(scale: scale);
      canvas.drawPicture(picture);
    }
  }

  @override
  bool shouldRepaint(covariant DxfCanvasPainter oldDelegate) {
    final scaleChanged = (oldDelegate.scale - scale).abs() > scale * 0.2;
    return oldDelegate.document != document ||
        oldDelegate.hiddenLayers != hiddenLayers ||
        oldDelegate.cacheManager != cacheManager ||
        scaleChanged;
  }
}
