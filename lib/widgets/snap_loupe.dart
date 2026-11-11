import 'package:flutter/material.dart';

import '../models/annotation.dart';
import '../models/drawn_object.dart';
import '../models/dxf_models.dart';
import '../models/snap_models.dart';
import '../utils/dxf_overlays.dart';
import '../utils/layer_cache.dart';
import '../utils/marker_clusterer.dart';
import 'drawn_objects_painter.dart';
import 'drawn_texts_painter.dart';
import 'dxf_overlay_painter.dart';
import 'marker_painter.dart';
import 'snap_glyph.dart';

/// Лупа-увеличитель у пальца/курсора: показывает увеличенную область чертежа
/// вокруг точки привязки, чтобы точно попасть в узел. Рисует всё, что видно
/// в основном виде: линии слоёв, точки DXF, подписи DXF, маркеры точек,
/// нарисованные объекты и их тексты.
class SnapLoupe extends StatelessWidget {
  final DxfLayerCacheManager cacheManager;
  final Set<String> hiddenLayers;

  /// Локальная координата, вокруг которой строится увеличение
  /// (точка привязки, а если её нет — позиция пальца).
  final Offset aimLocal;

  /// Текущая найденная привязка (глиф в центре лупы).
  final SnapResult? snap;

  /// Опорный масштаб основного вида (локальные единицы → пиксели).
  final double mainScale;

  /// Кратность увеличения относительно основного вида.
  final double zoom;

  /// Размер лупы (диаметр), px.
  final double size;

  /// Уже поставленные точки измерения (локальные) — контекст в лупе.
  final List<Offset> measurementPoints;
  final bool closed;

  /// Нарисованные пользователем объекты — показываем и в лупе.
  final List<DrawnObject> drawnObjects;
  final double minX, maxY;

  /// Диагональ чертежа (для продления «прямой» в лупе).
  final double extent;

  /// Единицы измерения (для подписи размера в лупе).
  final String units;

  /// Точки/подписи DXF и маркеры точек — чтобы в лупе были все элементы.
  final DxfOverlays? overlays;
  final List<Annotation> annotations;
  final DxfDocument? document;

  const SnapLoupe({
    super.key,
    required this.cacheManager,
    required this.hiddenLayers,
    required this.aimLocal,
    required this.snap,
    required this.mainScale,
    this.zoom = 2.6,
    this.size = 124,
    this.measurementPoints = const [],
    this.closed = false,
    this.drawnObjects = const [],
    this.minX = 0,
    this.maxY = 0,
    this.extent = 0,
    this.units = 'm',
    this.overlays,
    this.annotations = const [],
    this.document,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SnapLoupePainter(
          cacheManager: cacheManager,
          hiddenLayers: hiddenLayers,
          aimLocal: aimLocal,
          snap: snap,
          mainScale: mainScale,
          zoom: zoom,
          measurementPoints: measurementPoints,
          closed: closed,
          drawnObjects: drawnObjects,
          minX: minX,
          maxY: maxY,
          extent: extent,
          units: units,
          overlays: overlays,
          annotations: annotations,
          document: document,
        ),
      ),
    );
  }
}

class _SnapLoupePainter extends CustomPainter {
  final DxfLayerCacheManager cacheManager;
  final Set<String> hiddenLayers;
  final Offset aimLocal;
  final SnapResult? snap;
  final double mainScale;
  final double zoom;
  final List<Offset> measurementPoints;
  final bool closed;
  final List<DrawnObject> drawnObjects;
  final double minX, maxY;
  final double extent;
  final String units;
  final DxfOverlays? overlays;
  final List<Annotation> annotations;
  final DxfDocument? document;

  _SnapLoupePainter({
    required this.cacheManager,
    required this.hiddenLayers,
    required this.aimLocal,
    required this.snap,
    required this.mainScale,
    required this.zoom,
    required this.measurementPoints,
    required this.closed,
    required this.drawnObjects,
    required this.minX,
    required this.maxY,
    required this.extent,
    required this.units,
    required this.overlays,
    required this.annotations,
    required this.document,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final circle = Rect.fromCircle(center: center, radius: radius);

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF212830));

    // Увеличенный вид чертежа: те же кэши слоёв, но с масштабом лупы.
    final s = mainScale * zoom;
    canvas.translate(center.dx, center.dy);
    canvas.scale(s, s);
    canvas.translate(-aimLocal.dx, -aimLocal.dy);

    for (final layer in cacheManager.layerNames) {
      if (hiddenLayers.contains(layer)) continue;
      final cache = cacheManager.getLayerCache(layer);
      if (cache == null) continue;
      canvas.drawPicture(cache.getPicture(scale: mainScale));
    }

    // Нарисованные пользователем объекты (точки/углы, к которым привязка).
    if (drawnObjects.isNotEmpty) {
      final visible = Rect.fromCenter(
        center: aimLocal,
        width: radius * 2 / s,
        height: radius * 2 / s,
      );
      DrawnObjectsPainter(
        objects: drawnObjects,
        minX: minX,
        maxY: maxY,
        scale: mainScale,
        extent: extent,
        rayClip: visible,
      ).paint(canvas, size);
    }

    // Контекст измерения: уже поставленные точки и стороны.
    if (measurementPoints.isNotEmpty) {
      final linePaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2 / s
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < measurementPoints.length - 1; i++) {
        canvas.drawLine(
            measurementPoints[i], measurementPoints[i + 1], linePaint);
      }
      if (closed && measurementPoints.length >= 3) {
        canvas.drawLine(
          measurementPoints.last,
          measurementPoints.first,
          linePaint..color = Colors.cyanAccent,
        );
      }
      final dotPaint = Paint()..color = Colors.orange;
      for (final p in measurementPoints) {
        canvas.drawCircle(p, 4 / s, dotPaint);
      }
    }

    // Перекрестие в точке прицеливания.
    final crossPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1 / s
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(aimLocal.dx - 10 / s, aimLocal.dy),
      Offset(aimLocal.dx + 10 / s, aimLocal.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(aimLocal.dx, aimLocal.dy - 10 / s),
      Offset(aimLocal.dx, aimLocal.dy + 10 / s),
      crossPaint,
    );
    canvas.restore();

    // Экранные слои в увеличенном виде: точки DXF, подписи DXF, маркеры
    // точек, нарисованные тексты — чтобы в лупе были все элементы.
    final loupeMatrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-aimLocal.dx, -aimLocal.dy, 0, 1);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    if (overlays != null) {
      DxfPointPainter(
        overlays: overlays!,
        matrix: loupeMatrix,
        minX: minX,
        maxY: maxY,
        hiddenLayers: hiddenLayers,
      ).paint(canvas, size);
      DxfTextPainter(
        overlays: overlays!,
        matrix: loupeMatrix,
        minX: minX,
        maxY: maxY,
        hiddenLayers: hiddenLayers,
      ).paint(canvas, size);
    }
    if (annotations.isNotEmpty && document != null) {
      final clusters = MarkerClusterer().clusterize(
        annotations: annotations,
        document: document!,
        matrix: loupeMatrix,
        minDistancePx: 18.0,
      );
      ClusteredMarkerPainter(clusters: clusters).paint(canvas, size);
    }
    if (drawnObjects.isNotEmpty) {
      DrawnTextsPainter(
        objects: drawnObjects,
        matrix: loupeMatrix,
        minX: minX,
        maxY: maxY,
        units: units,
        scale: s,
      ).paint(canvas, size);
    }
    canvas.restore();

    // Рамка лупы.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black45,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white70,
    );

    // Маркер привязки в центре лупы.
    if (snap != null) {
      drawSnapGlyph(canvas, center, snap!.type, size: 15);
    }
  }

  @override
  bool shouldRepaint(covariant _SnapLoupePainter old) =>
      old.aimLocal != aimLocal ||
      old.snap != snap ||
      old.mainScale != mainScale ||
      old.zoom != zoom ||
      old.hiddenLayers != hiddenLayers ||
      old.measurementPoints != measurementPoints ||
      old.closed != closed ||
      old.drawnObjects != drawnObjects ||
      old.minX != minX ||
      old.maxY != maxY ||
      old.extent != extent ||
      old.units != units ||
      old.overlays != overlays ||
      old.annotations != annotations ||
      old.document != document;
}
