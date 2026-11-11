import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import '../models/dxf_models.dart';

final RegExp _uplusRe = RegExp(r'\\U\+([0-9A-Fa-f]{4,6})');

/// Декодирует DXF-эскейпы \U+XXXX (так пишется кириллица в DXF).
String _unescapeDxf(String v) {
  if (!v.contains(r'\U+')) return v;
  return v.replaceAllMapped(_uplusRe, (m) {
    final code = int.tryParse(m[1]!, radix: 16);
    if (code == null) return m[0]!;
    return String.fromCharCode(code);
  });
}

class _Pair {
  final int code;
  final String value;
  _Pair(this.code, String value) : value = _unescapeDxf(value);
}

class _EntityResult {
  final DxfEntity entity;
  final int nextIndex;
  _EntityResult(this.entity, this.nextIndex);
}

class _LayerResult {
  final DxfLayer layer;
  final int nextIndex;
  _LayerResult(this.layer, this.nextIndex);
}

class _BlockResult {
  final DxfBlock block;
  final int nextIndex;
  _BlockResult(this.block, this.nextIndex);
}

class DxfParser {
  Future<DxfDocument> parseBytes(Uint8List bytes) async {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = LineSplitter.split(content).toList();
    return _parseLines(lines);
  }

  /// Оставлен для совместимости.
  Future<DxfDocument> parseFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return parseBytes(bytes);
  }

  DxfDocument _parseLines(List<String> lines) {
    // Разбиваем на пары (код, значение).
    final items = <_Pair>[];
    for (int k = 0; k + 1 < lines.length; k += 2) {
      final code = int.tryParse(lines[k].trim()) ?? -1;
      items.add(_Pair(code, lines[k + 1].trim()));
    }

    final layers = <DxfLayer>[];
    final entities = <DxfEntity>[];
    final blocks = <String, DxfBlock>{};

    String? section;
    int p = 0;
    while (p < items.length) {
      final it = items[p];
      if (it.code == 0 && it.value == 'SECTION') {
        section = (p + 1 < items.length && items[p + 1].code == 2)
            ? items[p + 1].value
            : null;
        p += 2;
        continue;
      }
      if (it.code == 0 && it.value == 'ENDSEC') {
        section = null;
        p++;
        continue;
      }
      if (it.code == 0 && it.value == 'EOF') {
        break;
      }

      if (section == 'TABLES' && it.code == 0 && it.value == 'LAYER') {
        final r = _parseLayer(items, p);
        if (r != null) {
          layers.add(r.layer);
          p = r.nextIndex;
          continue;
        }
      } else if (section == 'BLOCKS' && it.code == 0 && it.value == 'BLOCK') {
        final r = _parseBlock(items, p);
        if (r != null) {
          blocks[r.block.name] = r.block;
          p = r.nextIndex;
          continue;
        }
      } else if (section == 'ENTITIES' && it.code == 0) {
        final r = _parseEntity(items, p, it.value);
        if (r != null) {
          entities.add(r.entity);
          p = r.nextIndex;
          continue;
        }
      }
      p++;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    final sampleX = <double>[];
    final sampleY = <double>[];
    void update(double x, double y) {
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      sampleX.add(x);
      sampleY.add(y);
    }

    for (final e in entities) {
      _updateExtents(e, update, blocks, 0);
    }

    // Устойчивые границы: отбрасываем 0.5% крайних точек с каждой стороны,
    // чтобы одиночный выброс (частая ошибка координат в съёмке) не сжимал
    // весь чертёж в точку при вписывании в экран.
    if (sampleX.length >= 50) {
      sampleX.sort();
      sampleY.sort();
      final n = sampleX.length;
      final lo = (n * 0.005).floor().clamp(0, n - 1);
      final hi = ((n * 0.995).ceil() - 1).clamp(0, n - 1);
      minX = sampleX[lo];
      maxX = sampleX[hi];
      minY = sampleY[lo];
      maxY = sampleY[hi];
    }

    if (minX.isInfinite) {
      minX = 0;
      minY = 0;
      maxX = 100;
      maxY = 100;
    }

    return DxfDocument(
      layers: layers,
      entities: entities,
      blocks: blocks,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );
  }

  // ---- helpers ---------------------------------------------------------

  double? _dbl(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    return double.tryParse(values.first.replaceAll(',', '.'));
  }

  int? _int(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    return int.tryParse(values.first);
  }

  String? _first(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  _LayerResult? _parseLayer(List<_Pair> items, int start) {
    String? name;
    int colorIndex = 7;
    int? trueColor;
    int? lineWeight;
    int flags = 0;
    int p = start + 1;
    while (p < items.length && items[p].code != 0) {
      final it = items[p];
      switch (it.code) {
        case 2:
          name = it.value;
          break;
        case 62:
          colorIndex = int.tryParse(it.value) ?? 7;
          break;
        case 420:
          trueColor = int.tryParse(it.value);
          break;
        case 370:
          lineWeight = int.tryParse(it.value);
          break;
        case 70:
          flags = int.tryParse(it.value) ?? 0;
          break;
      }
      p++;
    }
    if (name == null) return null;
    if (colorIndex < 0) colorIndex = -colorIndex;
    return _LayerResult(
      DxfLayer(
        name: name,
        colorIndex: colorIndex,
        trueColor: trueColor,
        lineWeight: lineWeight,
        isOff: (flags & 1) != 0,
        isFrozen: (flags & 2) != 0,
      ),
      p,
    );
  }

  _BlockResult? _parseBlock(List<_Pair> items, int start) {
    String? name;
    double baseX = 0, baseY = 0;
    int p = start + 1;
    final blockEntities = <DxfEntity>[];
    while (p < items.length) {
      final it = items[p];
      if (it.code == 0) {
        if (it.value == 'ENDBLK') {
          p++;
          break;
        }
        final r = _parseEntity(items, p, it.value);
        if (r != null) {
          blockEntities.add(r.entity);
          p = r.nextIndex;
          continue;
        }
        // Неизвестная сущность — пропускаем её свойства.
        p++;
        while (p < items.length && items[p].code != 0) {
          p++;
        }
        continue;
      }
      switch (it.code) {
        case 2:
          name ??= it.value;
          break;
        case 10:
          baseX = double.tryParse(it.value) ?? baseX;
          break;
        case 20:
          baseY = double.tryParse(it.value) ?? baseY;
          break;
      }
      p++;
    }
    if (name == null) return null;
    double bMinX = double.infinity, bMinY = double.infinity;
    double bMaxX = double.negativeInfinity, bMaxY = double.negativeInfinity;
    void bupd(double x, double y) {
      if (x < bMinX) bMinX = x;
      if (y < bMinY) bMinY = y;
      if (x > bMaxX) bMaxX = x;
      if (y > bMaxY) bMaxY = y;
    }

    for (final be in blockEntities) {
      _updateExtents(be, bupd, const <String, DxfBlock>{}, 0);
    }
    if (bMinX.isInfinite) {
      bMinX = 0;
      bMinY = 0;
      bMaxX = 0;
      bMaxY = 0;
    }
    return _BlockResult(
      DxfBlock(
        name: name,
        baseX: baseX,
        baseY: baseY,
        minX: bMinX,
        minY: bMinY,
        maxX: bMaxX,
        maxY: bMaxY,
        entities: blockEntities,
      ),
      p,
    );
  }

  _EntityResult? _parseEntity(List<_Pair> items, int start, String type) {
    int p = start + 1;
    final props = <int, List<String>>{};
    while (p < items.length && items[p].code != 0) {
      props.putIfAbsent(items[p].code, () => []).add(items[p].value);
      p++;
    }

    final layer = _first(props[8]) ?? '0';
    final colorIndex = _int(props[62]);
    final trueColor = _int(props[420]);
    final lineWeight = _int(props[370]);
    // Высота объекта (H в режиме «Координаты»): 30 — точка вставки/центр,
    // 38 — отметка LW-полилинии.
    final elevation = _dbl(props[30]) ?? _dbl(props[38]) ?? 0.0;

    switch (type) {
      case 'LINE':
        return _EntityResult(
          DxfLine(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            x1: _dbl(props[10]) ?? 0,
            y1: _dbl(props[20]) ?? 0,
            x2: _dbl(props[11]) ?? 0,
            y2: _dbl(props[21]) ?? 0,
          ),
          p,
        );
      case 'LWPOLYLINE':
        final xs = props[10] ?? const <String>[];
        final ys = props[20] ?? const <String>[];
        final bulges = props[42] ?? const <String>[];
        final verts = <DxfVertex>[];
        for (int j = 0; j < xs.length && j < ys.length; j++) {
          verts.add(DxfVertex(
            double.tryParse(xs[j]) ?? 0,
            double.tryParse(ys[j]) ?? 0,
            j < bulges.length ? (double.tryParse(bulges[j]) ?? 0) : 0,
          ));
        }
        final flags = _int(props[70]) ?? 0;
        return _EntityResult(
          DxfLwPolyline(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            vertices: verts,
            isClosed: (flags & 1) == 1,
          ),
          p,
        );
      case 'POLYLINE':
        return _parsePolyline(items, p, layer, colorIndex, trueColor,
            lineWeight, props, elevation);
      case 'CIRCLE':
        return _EntityResult(
          DxfCircle(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            cx: _dbl(props[10]) ?? 0,
            cy: _dbl(props[20]) ?? 0,
            radius: _dbl(props[40]) ?? 0,
          ),
          p,
        );
      case 'ARC':
        return _EntityResult(
          DxfArc(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            cx: _dbl(props[10]) ?? 0,
            cy: _dbl(props[20]) ?? 0,
            radius: _dbl(props[40]) ?? 0,
            startAngle: _dbl(props[50]) ?? 0,
            endAngle: _dbl(props[51]) ?? 360,
          ),
          p,
        );
      case 'ELLIPSE':
        return _EntityResult(
          DxfEllipse(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            cx: _dbl(props[10]) ?? 0,
            cy: _dbl(props[20]) ?? 0,
            majorX: _dbl(props[11]) ?? 1,
            majorY: _dbl(props[21]) ?? 0,
            ratio: _dbl(props[40]) ?? 1,
            startParam: _dbl(props[41]) ?? 0,
            endParam: _dbl(props[42]) ?? 6.283185307179586,
          ),
          p,
        );
      case 'POINT':
        return _EntityResult(
          DxfPoint(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            x: _dbl(props[10]) ?? 0,
            y: _dbl(props[20]) ?? 0,
          ),
          p,
        );
      case 'TEXT':
      case 'MTEXT':
        final content =
            type == 'MTEXT' ? _mtextContent(props) : (_first(props[1]) ?? '');
        return _EntityResult(
          DxfText(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            x: _dbl(props[10]) ?? 0,
            y: _dbl(props[20]) ?? 0,
            content: content,
            height: _dbl(props[40]) ?? 2.5,
            rotation: _dbl(props[50]) ?? 0,
          ),
          p,
        );
      case 'INSERT':
        return _EntityResult(
          DxfInsert(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            blockName: _first(props[2]) ?? '',
            x: _dbl(props[10]) ?? 0,
            y: _dbl(props[20]) ?? 0,
            scaleX: _dbl(props[41]) ?? 1,
            scaleY: _dbl(props[42]) ?? 1,
            rotation: _dbl(props[50]) ?? 0,
          ),
          p,
        );
      case 'SOLID':
      case 'TRACE':
      case '3DFACE':
        final p1 = DxfVertex(_dbl(props[10]) ?? 0, _dbl(props[20]) ?? 0);
        final p2 = DxfVertex(_dbl(props[11]) ?? 0, _dbl(props[21]) ?? 0);
        final p3 = DxfVertex(_dbl(props[12]) ?? 0, _dbl(props[22]) ?? 0);
        final p4 = DxfVertex(_dbl(props[13]) ?? p3.x, _dbl(props[23]) ?? p3.y);
        // У SOLID/TRACE порядок углов в файле — «змейкой» (3 и 4 меняются).
        final points = type == '3DFACE' ? [p1, p2, p3, p4] : [p1, p2, p4, p3];
        return _EntityResult(
          DxfSolid(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            points: points,
          ),
          p,
        );
      case 'SPLINE':
        final flags = _int(props[70]) ?? 0;
        final fitXs = props[11] ?? const <String>[];
        final fitYs = props[21] ?? const <String>[];
        final ctrlXs = props[10] ?? const <String>[];
        final ctrlYs = props[20] ?? const <String>[];
        final pts = <DxfVertex>[];
        if (fitXs.isNotEmpty && fitXs.length == fitYs.length) {
          for (int j = 0; j < fitXs.length; j++) {
            pts.add(DxfVertex(
              double.tryParse(fitXs[j]) ?? 0,
              double.tryParse(fitYs[j]) ?? 0,
            ));
          }
        } else {
          for (int j = 0; j < ctrlXs.length && j < ctrlYs.length; j++) {
            pts.add(DxfVertex(
              double.tryParse(ctrlXs[j]) ?? 0,
              double.tryParse(ctrlYs[j]) ?? 0,
            ));
          }
        }
        return _EntityResult(
          DxfSpline(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            points: pts,
            isClosed: (flags & 1) == 1,
          ),
          p,
        );
      case 'RAY':
      case 'XLINE':
        return _EntityResult(
          DxfRay(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            x: _dbl(props[10]) ?? 0,
            y: _dbl(props[20]) ?? 0,
            dx: _dbl(props[11]) ?? 1,
            dy: _dbl(props[21]) ?? 0,
            isInfinite: type == 'XLINE',
          ),
          p,
        );
      case 'DIMENSION':
        // Размер рисуется через свой анонимный блок (геометрия в WCS).
        return _EntityResult(
          DxfInsert(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            blockName: _first(props[2]) ?? '',
            x: 0,
            y: 0,
          ),
          p,
        );
      case 'LEADER':
        final xs = props[10] ?? const <String>[];
        final ys = props[20] ?? const <String>[];
        final verts = <DxfVertex>[];
        for (int j = 0; j < xs.length && j < ys.length; j++) {
          verts.add(DxfVertex(
            double.tryParse(xs[j]) ?? 0,
            double.tryParse(ys[j]) ?? 0,
          ));
        }
        return _EntityResult(
          DxfPolyline(
            layer: layer,
            colorIndex: colorIndex,
            trueColor: trueColor,
            lineWeight: lineWeight,
            elevation: elevation,
            vertices: verts,
          ),
          p,
        );
      default:
        return null;
    }
  }

  _EntityResult? _parsePolyline(
    List<_Pair> items,
    int afterProps,
    String layer,
    int? colorIndex,
    int? trueColor,
    int? lineWeight,
    Map<int, List<String>> props,
    double elevation,
  ) {
    final flags = _int(props[70]) ?? 0;
    final isClosed = (flags & 1) == 1;
    final verts = <DxfVertex>[];
    int p = afterProps;
    while (p < items.length) {
      final it = items[p];
      if (it.code != 0) {
        p++;
        continue;
      }
      if (it.value == 'VERTEX') {
        int q = p + 1;
        final vp = <int, List<String>>{};
        while (q < items.length && items[q].code != 0) {
          vp.putIfAbsent(items[q].code, () => []).add(items[q].value);
          q++;
        }
        verts.add(DxfVertex(
          _dbl(vp[10]) ?? 0,
          _dbl(vp[20]) ?? 0,
          _dbl(vp[42]) ?? 0,
        ));
        p = q;
        continue;
      }
      if (it.value == 'SEQEND') {
        p++;
        break;
      }
      break;
    }
    return _EntityResult(
      DxfPolyline(
        layer: layer,
        colorIndex: colorIndex,
        trueColor: trueColor,
        lineWeight: lineWeight,
        elevation: elevation,
        vertices: verts,
        isClosed: isClosed,
      ),
      p,
    );
  }

  String _mtextContent(Map<int, List<String>> props) {
    final buffer = StringBuffer();
    for (final chunk in props[3] ?? const <String>[]) {
      buffer.write(chunk);
    }
    buffer.write(_first(props[1]) ?? '');
    var text = buffer.toString();
    text = text.replaceAll('\\P', '\n').replaceAll('\\~', ' ');
    text = text.replaceAll('{', '').replaceAll('}', '');
    return text.trim();
  }

  void _updateExtents(DxfEntity e, void Function(double, double) update,
      Map<String, DxfBlock> blocks, int depth) {
    switch (e) {
      case DxfLine x:
        update(x.x1, x.y1);
        update(x.x2, x.y2);
      case DxfLwPolyline x:
        for (final v in x.vertices) {
          update(v.x, v.y);
        }
      case DxfPolyline x:
        for (final v in x.vertices) {
          update(v.x, v.y);
        }
      case DxfCircle x:
        update(x.cx - x.radius, x.cy - x.radius);
        update(x.cx + x.radius, x.cy + x.radius);
      case DxfArc x:
        update(x.cx - x.radius, x.cy - x.radius);
        update(x.cx + x.radius, x.cy + x.radius);
      case DxfEllipse x:
        final r = math.sqrt(x.majorX * x.majorX + x.majorY * x.majorY);
        update(x.cx - r, x.cy - r);
        update(x.cx + r, x.cy + r);
      case DxfPoint x:
        update(x.x, x.y);
      case DxfText x:
        update(x.x, x.y);
      case DxfInsert x:
        final block = blocks[x.blockName];
        if (block == null || depth >= 8) {
          update(x.x, x.y);
        } else {
          // Считаем bbox блока, затем переносим его углы вставкой,
          // иначе чертежи из блоков имеют нулевые границы.
          double bMinX = double.infinity, bMinY = double.infinity;
          double bMaxX = double.negativeInfinity;
          double bMaxY = double.negativeInfinity;
          void local(double px, double py) {
            if (px < bMinX) bMinX = px;
            if (py < bMinY) bMinY = py;
            if (px > bMaxX) bMaxX = px;
            if (py > bMaxY) bMaxY = py;
          }

          for (final be in block.entities) {
            _updateExtents(be, local, blocks, depth + 1);
          }
          if (bMinX.isFinite) {
            final rad = x.rotation * math.pi / 180;
            final cosr = math.cos(rad), sinr = math.sin(rad);
            final corners = [
              [bMinX, bMinY],
              [bMaxX, bMinY],
              [bMaxX, bMaxY],
              [bMinX, bMaxY],
            ];
            for (final c in corners) {
              final dx = (c[0] - block.baseX) * x.scaleX;
              final dy = (c[1] - block.baseY) * x.scaleY;
              final wx = x.x + dx * cosr - dy * sinr;
              final wy = x.y + dx * sinr + dy * cosr;
              update(wx, wy);
            }
          }
        }
      case DxfSolid x:
        for (final v in x.points) {
          update(v.x, v.y);
        }
      case DxfSpline x:
        for (final v in x.points) {
          update(v.x, v.y);
        }
      case DxfRay _:
        break; // бесконечная — не влияет на границы
    }
  }
}
