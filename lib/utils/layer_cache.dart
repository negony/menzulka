import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import 'bulge_arc.dart';
import 'dxf_overlays.dart';

/// РљСЌС€ РѕС‚СЂРёСЃРѕРІРєРё РѕРґРЅРѕРіРѕ СЃР»РѕСЏ.
///
/// Р“РµРѕРјРµС‚СЂРёСЏ СЂРёСЃСѓРµС‚СЃСЏ РІ РјРёСЂРѕРІС‹С… РєРѕРѕСЂРґРёРЅР°С‚Р°С… DXF, Р° РіР»РѕР±Р°Р»СЊРЅР°СЏ С‚СЂР°РЅСЃС„РѕСЂРјР°С†РёСЏ
/// С…РѕР»СЃС‚Р° РїРµСЂРµРІРѕРґРёС‚ РµС‘ РІ Р»РѕРєР°Р»СЊРЅС‹Рµ РєРѕРѕСЂРґРёРЅР°С‚С‹ РІСЊСЋРµСЂР° (СЃРґРІРёРі + РёРЅРІРµСЂСЃРёСЏ Y).
/// РўРѕС‡РєРё Рё С‚РµРєСЃС‚ Р·РґРµСЃСЊ РЅРµ СЂРёСЃСѓСЋС‚СЃСЏ вЂ” РѕРЅРё РІС‹РІРѕРґСЏС‚СЃСЏ СЌРєСЂР°РЅРЅС‹РјРё РѕРІРµСЂР»РµСЏРјРё
/// (СЃРј. [buildDxfOverlays]), С‡С‚РѕР±С‹ РЅРµ РїРёРєСЃРµР»РёС‚СЊ Рё РЅРµ РїСЂРѕРїР°РґР°С‚СЊ РїСЂРё Р·СѓРјРµ.
class LayerCache {
  final String layerName;
  final List<DxfEntity> entities;
  final double offsetX;
  final double offsetY;
  final Map<String, DxfLayer> layers;
  final Map<String, DxfBlock> blocks;
  final double worldSpan;

  static const double _insertPx = 5.0;

  ui.Picture? _cachedPicture;
  double _cachedScale = 0;
  bool _isDirty = true;

  LayerCache({
    required this.layerName,
    required this.entities,
    required this.offsetX,
    required this.offsetY,
    required this.layers,
    required this.blocks,
    required this.worldSpan,
  });

  ui.Picture getPicture({required double scale}) {
    if (_cachedPicture != null && !_isDirty && !_scaleChanged(scale)) {
      return _cachedPicture!;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // world -> local: СЃРґРІРёРі Рє (0,0) Рё РёРЅРІРµСЂСЃРёСЏ Y.
    canvas.translate(-offsetX, offsetY);
    canvas.scale(1, -1);

    final safeScale = scale <= 0 ? 1.0 : scale;
    final insertArm = _insertPx / safeScale;

    for (final entity in entities) {
      _drawEntity(
        canvas,
        entity,
        scale: safeScale,
        insertArm: insertArm,
        blockColor: null,
        blockLw: null,
        depth: 0,
      );
    }

    _cachedPicture = recorder.endRecording();
    _cachedScale = safeScale;
    _isDirty = false;
    return _cachedPicture!;
  }

  bool _scaleChanged(double scale) {
    if (_cachedScale <= 0) return true;
    return (scale - _cachedScale).abs() > _cachedScale * 0.2;
  }

  void invalidate() {
    _isDirty = true;
    _cachedPicture?.dispose();
    _cachedPicture = null;
  }

  void _drawEntity(
    Canvas canvas,
    DxfEntity entity, {
    required double scale,
    required double insertArm,
    Color? blockColor,
    int? blockLw,
    required int depth,
  }) {
    final color = resolveDxfColor(entity, layers, blockColor);
    final lw = resolveDxfLineWeight(entity, layers, blockLw);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = lineWeightToPx(lw) / scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (entity) {
      case DxfLine e:
        canvas.drawLine(Offset(e.x1, e.y1), Offset(e.x2, e.y2), stroke);
      case DxfLwPolyline e:
        _drawPolyline(canvas, e.vertices, e.isClosed, stroke);
      case DxfPolyline e:
        _drawPolyline(canvas, e.vertices, e.isClosed, stroke);
      case DxfArc e:
        _drawArc(canvas, e, stroke);
      case DxfEllipse e:
        _drawEllipse(canvas, e, stroke);
      case DxfCircle e:
        canvas.drawCircle(Offset(e.cx, e.cy), e.radius, stroke);
      case DxfSolid e:
        _drawSolid(canvas, e, color);
      case DxfSpline e:
        _drawPolyline(canvas, e.points, e.isClosed, stroke);
      case DxfRay e:
        _drawRay(canvas, e, stroke);
      case DxfInsert e:
        _drawInsert(canvas, e, color, lw, scale, insertArm, depth);
      case DxfPoint _:
      case DxfText _:
        // Р РёСЃСѓСЋС‚СЃСЏ СЌРєСЂР°РЅРЅС‹РјРё РѕРІРµСЂР»РµСЏРјРё.
        break;
    }
  }

  void _drawPolyline(
      Canvas canvas, List<DxfVertex> verts, bool closed, Paint paint) {
    if (verts.isEmpty) return;
    final path = Path();
    path.moveTo(verts.first.x, verts.first.y);
    final n = verts.length;
    final segCount = closed ? n : n - 1;
    for (int i = 0; i < segCount; i++) {
      final a = verts[i];
      final b = verts[(i + 1) % n];
      if (a.bulge.abs() < 1e-9) {
        path.lineTo(b.x, b.y);
      } else {
        for (final pt in bulgeArcPoints(a.x, a.y, b.x, b.y, a.bulge)) {
          path.lineTo(pt.dx, pt.dy);
        }
      }
    }
    if (closed) path.close();
    canvas.drawPath(path, paint);
  }

  void _drawArc(Canvas canvas, DxfArc e, Paint paint) {
    var start = e.startAngle * math.pi / 180;
    var end = e.endAngle * math.pi / 180;
    if (end <= start) end += 2 * math.pi;
    final segments = math.max(8, ((end - start) / (math.pi / 16)).ceil());
    final path = Path();
    for (int i = 0; i <= segments; i++) {
      final a = start + (end - start) * i / segments;
      final x = e.cx + e.radius * math.cos(a);
      final y = e.cy + e.radius * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawEllipse(Canvas canvas, DxfEllipse e, Paint paint) {
    final mx = e.majorX, my = e.majorY;
    final nx = -my * e.ratio, ny = mx * e.ratio;
    var start = e.startParam;
    var end = e.endParam;
    final full = (end - start).abs() >= 2 * math.pi - 1e-6;
    if (full) {
      start = 0;
      end = 2 * math.pi;
    }
    final segments = full ? 72 : 48;
    final path = Path();
    for (int i = 0; i <= segments; i++) {
      final t = start + (end - start) * i / segments;
      final x = e.cx + mx * math.cos(t) + nx * math.sin(t);
      final y = e.cy + my * math.cos(t) + ny * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (full) path.close();
    canvas.drawPath(path, paint);
  }

  void _drawInsert(
    Canvas canvas,
    DxfInsert e,
    Color color,
    int lw,
    double scale,
    double insertArm,
    int depth,
  ) {
    final block = blocks[e.blockName];
    if (block == null || depth > 8) {
      final p = Paint()
        ..color = color
        ..strokeWidth = lineWeightToPx(lw) / scale
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(e.x - insertArm, e.y - insertArm),
          Offset(e.x + insertArm, e.y + insertArm), p);
      canvas.drawLine(Offset(e.x - insertArm, e.y + insertArm),
          Offset(e.x + insertArm, e.y - insertArm), p);
      return;
    }
    // Р•СЃР»Рё СЃРёРјРІРѕР» Р±Р»РѕРєР° РЅР° СЌРєСЂР°РЅРµ СЃР»РёС€РєРѕРј РјР°Р» (С‡Р°СЃС‚Рѕ РІ СЃСЉС‘РјРєРµ: INSERT
    // СЃ РјР°СЃС€С‚Р°Р±РѕРј 0.002), СЂРёСЃСѓРµРј С‚РѕС‡РєСѓ РїРѕСЃС‚РѕСЏРЅРЅРѕРіРѕ СЂР°Р·РјРµСЂР°, РёРЅР°С‡Рµ С‚РѕС‡РєРё
    // СЃСЉС‘РјРєРё РЅРµ РІРёРґРЅС‹ РЅР° РѕР±С‰РµРј РїР»Р°РЅРµ.
    final blockW = block.maxX - block.minX;
    final blockH = block.maxY - block.minY;
    final hasBounds = block.maxX > block.minX || block.maxY > block.minY;
    final blockScreen =
        math.max(blockW * e.scaleX.abs(), blockH * e.scaleY.abs()) * scale;
    if (hasBounds && blockScreen < 3.0) {
      canvas.drawCircle(
        Offset(e.x, e.y),
        2.0 / scale,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.save();
    canvas.translate(e.x, e.y);
    canvas.rotate(e.rotation * math.pi / 180);
    canvas.scale(e.scaleX, e.scaleY);
    canvas.translate(-block.baseX, -block.baseY);
    // РљРѕРјРїРµРЅСЃРёСЂСѓРµРј РјР°СЃС€С‚Р°Р± Р±Р»РѕРєР° РІ С‚РѕР»С‰РёРЅРµ С€С‚СЂРёС…Р°/СЂР°Р·РјРµСЂР°С…, РёРЅР°С‡Рµ РІРЅСѓС‚СЂРё
    // Р±Р»РѕРєР° СЃ РјР°СЃС€С‚Р°Р±РѕРј 0.002 С€С‚СЂРёС… СЃС‚Р°РЅРѕРІРёС‚СЃСЏ РІ 500 СЂР°Р· С‚РѕРЅСЊС€Рµ Рё РёСЃС‡РµР·Р°РµС‚.
    final uniform = math.sqrt((e.scaleX * e.scaleY).abs());
    final childScale = uniform > 1e-9 ? scale * uniform : scale;
    final childInsertArm =
        childScale > 1e-9 ? _insertPx / childScale : insertArm;
    for (final be in block.entities) {
      _drawEntity(
        canvas,
        be,
        scale: childScale,
        insertArm: childInsertArm,
        blockColor: color,
        blockLw: lw,
        depth: depth + 1,
      );
    }
    canvas.restore();
  }

  void _drawSolid(Canvas canvas, DxfSolid e, Color color) {
    if (e.points.isEmpty) return;
    final path = Path();
    path.moveTo(e.points.first.x, e.points.first.y);
    for (int i = 1; i < e.points.length; i++) {
      path.lineTo(e.points[i].x, e.points[i].y);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  void _drawRay(Canvas canvas, DxfRay e, Paint paint) {
    final mag = math.sqrt(e.dx * e.dx + e.dy * e.dy);
    if (mag < 1e-12) return;
    final ux = e.dx / mag, uy = e.dy / mag;
    final len = worldSpan * 2 + 1;
    final start = e.isInfinite
        ? Offset(e.x - ux * len, e.y - uy * len)
        : Offset(e.x, e.y);
    final end = Offset(e.x + ux * len, e.y + uy * len);
    canvas.drawLine(start, end, paint);
  }
}

class DxfLayerCacheManager {
  final Map<String, LayerCache> _layerCaches = {};

  void initialize(DxfDocument document) {
    _layerCaches.clear();
    final layerMap = {for (final l in document.layers) l.name: l};
    final span = math.sqrt(
      (document.maxX - document.minX) * (document.maxX - document.minX) +
          (document.maxY - document.minY) * (document.maxY - document.minY),
    );
    final byLayer = <String, List<DxfEntity>>{};
    for (final entity in document.entities) {
      byLayer.putIfAbsent(entity.layer, () => []).add(entity);
    }
    for (final entry in byLayer.entries) {
      _layerCaches[entry.key] = LayerCache(
        layerName: entry.key,
        entities: entry.value,
        offsetX: document.minX,
        offsetY: document.maxY,
        layers: layerMap,
        blocks: document.blocks,
        worldSpan: span,
      );
    }
  }

  LayerCache? getLayerCache(String layerName) => _layerCaches[layerName];

  /// Р’СЃРµ СЃР»РѕРё, РґР»СЏ РєРѕС‚РѕСЂС‹С… РµСЃС‚СЊ СЃСѓС‰РЅРѕСЃС‚Рё (РґР°Р¶Рµ РµСЃР»Рё РёС… РЅРµС‚ РІ С‚Р°Р±Р»РёС†Рµ LAYER).
  List<String> get layerNames => _layerCaches.keys.toList();

  void invalidateAll() {
    for (final cache in _layerCaches.values) {
      cache.invalidate();
    }
  }

  void dispose() {
    for (final cache in _layerCaches.values) {
      cache.invalidate();
    }
    _layerCaches.clear();
  }
}
