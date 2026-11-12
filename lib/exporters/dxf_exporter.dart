import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/annotation.dart';
import '../models/drawn_object.dart';
import '../models/dxf_models.dart';
import '../models/history_event.dart';
import '../models/measurement.dart';
import '../services/cad_converter.dart';
import '../services/cad_export_version.dart';
import '../services/database.dart';
import '../services/dxf_parser.dart';
import '../services/project_bundle.dart' show ExportPhotoQuality;
import '../utils/drawn_geometry.dart';
import '../utils/format_utils.dart';
import '../utils/photo_compressor.dart';

/// Режим экспорта.
enum DxfExportMode {
  /// Только DXF (геометрия).
  geometry,

  /// DXF + фото (ZIP: чертёж, фотографии точек, CSV точек, README).
  withPhotos,
}

/// Опции экспорта DXF.
class DxfExportOptions {
  final DxfExportMode mode;

  /// Включать точки (символ+номер) слоем «Точки».
  final bool includePoints;

  /// Включать измерения слоем «Измерения».
  final bool includeMeasurements;

  /// Пропускать нарисованные объекты скрытых слоёв.
  final bool visibleLayersOnly;

  /// Скрытые слои рисунков (для [visibleLayersOnly]).
  final Set<String> hiddenDrawnLayers;

  /// Качество фото в ZIP.
  final ExportPhotoQuality photoQuality;

  /// Если задано — экспорт в DWG этой версии (иначе DXF).
  final DwgExportVersion? dwgVersion;

  const DxfExportOptions({
    this.mode = DxfExportMode.geometry,
    this.includePoints = true,
    this.includeMeasurements = true,
    this.visibleLayersOnly = false,
    this.hiddenDrawnLayers = const {},
    this.photoQuality = ExportPhotoQuality.compact,
    this.dwgVersion,
  });

  DxfExportOptions copyWith({
    DxfExportMode? mode,
    bool? includePoints,
    bool? includeMeasurements,
    bool? visibleLayersOnly,
    Set<String>? hiddenDrawnLayers,
    ExportPhotoQuality? photoQuality,
    DwgExportVersion? dwgVersion,
  }) {
    return DxfExportOptions(
      mode: mode ?? this.mode,
      includePoints: includePoints ?? this.includePoints,
      includeMeasurements: includeMeasurements ?? this.includeMeasurements,
      visibleLayersOnly: visibleLayersOnly ?? this.visibleLayersOnly,
      hiddenDrawnLayers: hiddenDrawnLayers ?? this.hiddenDrawnLayers,
      photoQuality: photoQuality ?? this.photoQuality,
      dwgVersion: dwgVersion ?? this.dwgVersion,
    );
  }
}

/// Слой для точек (annotation) и измерений в экспортируемом DXF.
const String kDxfPointsLayer = 'Точки';
const String kDxfMeasurementsLayer = 'Измерения';

/// Экспорт DXF: исходный файл сохраняется побайтово, в него добавляются
/// таблица слоёв и сущности нарисованных объектов (и точек/измерений).
class DxfExportService {
  DxfExportService({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  int _codeWidth = 3;
  String _nl = '\n';
  bool _isOldFormat = false;

  // Современный формат (>= AC1021): сущности пишутся с handle и subclass-маркерами.
  bool _modern = false;
  String? _ownerHandle;
  String? _layerTableHandle;
  _HandleGen _handleGen = _HandleGen(0);

  // ---------- публичный API ----------

  Future<Uint8List> buildDxfBytes(
    String drawingId,
    DxfExportOptions options,
  ) async {
    final drawing = await _db.getDrawingById(drawingId);
    if (drawing == null) throw StateError('Чертёж не найден');
    final file = File(drawing.localFilePath);
    if (!await file.exists()) {
      throw StateError('Файл чертежа не найден: ${drawing.localFilePath}');
    }
    final original = await file.readAsBytes();
    final document = await DxfParser().parseBytes(original);
    final objects = await _db.getDrawnObjects(drawingId);
    final annotations = await _db.getAnnotations(drawingId: drawingId);
    final measurements = await _db.getMeasurementsForDrawing(drawingId);
    return buildFromParts(
      originalBytes: original,
      document: document,
      drawnObjects: objects,
      annotations: annotations,
      measurements: measurements,
      options: options,
      units: drawing.units,
      drawingName: drawing.name,
    );
  }

  Future<Uint8List> buildZipBytes(
    String drawingId,
    DxfExportOptions options, {
    void Function(int done, int total)? onProgress,
  }) async {
    final drawing = await _db.getDrawingById(drawingId);
    if (drawing == null) throw StateError('Чертёж не найден');
    final dxf = await buildDxfBytes(drawingId, options);
    final annotations = await _db.getAnnotations(drawingId: drawingId);
    return buildZipFromParts(
      dxfBytes: dxf,
      annotations: annotations,
      drawingName: drawing.name,
      options: options,
      onProgress: onProgress,
    );
  }

  Future<Uint8List> buildZipFromParts({
    required Uint8List dxfBytes,
    required List<Annotation> annotations,
    required String drawingName,
    required DxfExportOptions options,
    void Function(int done, int total)? onProgress,
  }) async {
    final archive = Archive();
    final safeName = _sanitizeFileName(drawingName);
    archive.addFile(ArchiveFile('$safeName.dxf', dxfBytes.length, dxfBytes));

    final totalPhotos =
        annotations.fold<int>(0, (sum, a) => sum + a.photos.length);
    var done = 0;
    final photoNamesByAnnotation = <String, List<String>>{};
    for (final ann in annotations) {
      final names = <String>[];
      for (final photo in ann.photos) {
        done++;
        final file = File(photo.localFilePath);
        if (await file.exists()) {
          var bytes = await file.readAsBytes();
          var ext = p.extension(photo.localFilePath);
          if (ext.isEmpty) ext = '.jpg';
          if (options.photoQuality == ExportPhotoQuality.compact) {
            bytes = await compressPhotoAsync(bytes);
            if (isJpegBytes(bytes)) ext = '.jpg';
          }
          final id = photo.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
          final name = 'photos/${ann.number}_$id$ext';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
          names.add(name);
        }
        onProgress?.call(done, totalPhotos);
      }
      photoNamesByAnnotation[ann.id] = names;
    }

    final csvBytes = utf8.encode(
        '\uFEFF${_buildPointsCsv(annotations, photoNamesByAnnotation)}');
    archive.addFile(ArchiveFile('points.csv', csvBytes.length, csvBytes));
    final readme = utf8.encode(_buildReadme(
        p.basenameWithoutExtension(drawingName), annotations.length));
    archive.addFile(ArchiveFile('README.txt', readme.length, readme));

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw StateError('Не удалось сформировать архив');
    return Uint8List.fromList(zipData);
  }

  /// Собирает DXF из исходных байтов и данных (без БД — тестируемо).
  Uint8List buildFromParts({
    required Uint8List originalBytes,
    required DxfDocument document,
    required List<DrawnObject> drawnObjects,
    required List<Annotation> annotations,
    required List<Measurement> measurements,
    required DxfExportOptions options,
    required String units,
    required String drawingName,
  }) {
    final src = _Source(originalBytes);
    _codeWidth = src.codeWidth;
    _nl = src.nl;
    _isOldFormat = src.isOldFormat;
    _modern = src.isModern;
    _ownerHandle = src.modelSpaceHandle;
    _layerTableHandle = src.layerTableHandle;
    _handleGen = _HandleGen(src.maxHandle);

    final entities = <String>[];
    final layers = <String>{};
    final extent = math.max(
      math.max(document.maxX - document.minX, document.maxY - document.minY),
      1e-3,
    );

    final visible = options.visibleLayersOnly
        ? drawnObjects
            .where((o) => !options.hiddenDrawnLayers.contains(o.layer))
            .toList()
        : drawnObjects;

    for (final o in visible) {
      layers.add(o.layer);
      entities.addAll(_entityForDrawn(o, units, extent));
    }
    if (options.includePoints && annotations.isNotEmpty) {
      layers.add(kDxfPointsLayer);
      for (final ann in annotations) {
        entities.addAll(_entityForAnnotation(ann, extent));
      }
    }
    if (options.includeMeasurements && measurements.isNotEmpty) {
      layers.add(kDxfMeasurementsLayer);
      for (final m in measurements) {
        entities.addAll(_entityForMeasurement(m, units, extent));
      }
    }

    final layerBlock = _buildLayerBlock(src, layers);
    final seed = _modern ? _handleGen.peek() : null;
    // Обновляем $EXTMIN/$EXTMAX: у некоторых исходников они «пустые» (1e+20),
    // из-за чего AutoCAD открывает чертёж без зума и экран пустой.
    var minX = document.minX, minY = document.minY;
    var maxX = document.maxX, maxY = document.maxY;
    void include(Offset pt) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    for (final o in visible) {
      for (final pt in o.points) {
        include(pt);
      }
    }
    for (final ann in annotations) {
      include(Offset(ann.dxfX, ann.dxfY));
    }
    for (final m in measurements) {
      if (m is DistanceMeasurement) {
        include(m.point1);
        include(m.point2);
      } else if (m is PolygonMeasurement) {
        for (final pt in m.points) {
          include(pt);
        }
      }
    }
    final extents = _Extents(minX, minY, maxX, maxY);
    return src.inject(layerBlock, entities.join(),
        newHandSeed: seed, extents: extents);
  }

  // ---------- сериализация сущностей ----------

  List<String> _entityForDrawn(DrawnObject o, String units, double extent) {
    final textHeight = o.height ?? extent / 200;
    final color = _colorCodes(o.color);
    final b = StringBuffer();
    switch (o.type) {
      case DrawnType.point:
        if (o.points.isEmpty) return const [];
        _entity(b, 'POINT', 'AcDbPoint', o.layer, color, (g) {
          _g(g, 10, _num(o.points.first.dx));
          _g(g, 20, _num(o.points.first.dy));
          _g(g, 30, '0.0');
        });
      case DrawnType.line:
        if (o.points.length < 2) return const [];
        _line(b, o.layer, color, o.points[0], o.points[1]);
      case DrawnType.ray:
        if (o.points.length < 2) return const [];
        final d = o.points[1] - o.points[0];
        final len = d.distance;
        if (len < 1e-9) return const [];
        _entity(b, 'XLINE', 'AcDbXline', o.layer, color, (g) {
          _g(g, 10, _num(o.points[0].dx));
          _g(g, 20, _num(o.points[0].dy));
          _g(g, 30, '0.0');
          _g(g, 11, _num(d.dx / len));
          _g(g, 21, _num(d.dy / len));
          _g(g, 31, '0.0');
        });
      case DrawnType.circle:
        if (o.points.length < 2) return const [];
        final r = (o.points[1] - o.points.first).distance;
        if (r <= 0) return const [];
        _entity(b, 'CIRCLE', 'AcDbCircle', o.layer, color, (g) {
          _g(g, 10, _num(o.points.first.dx));
          _g(g, 20, _num(o.points.first.dy));
          _g(g, 30, '0.0');
          _g(g, 40, _num(r));
        });
      case DrawnType.rectangle:
        if (o.points.length < 4) return const [];
        _lwpolyline(b, o.layer, color, o.points,
            closed: true, bulges: const []);
      case DrawnType.polyline:
        if (o.points.length < 2) return const [];
        _lwpolyline(b, o.layer, color, o.points,
            closed: false, bulges: const []);
      case DrawnType.cloud:
        if (o.points.length < 2) return const [];
        _lwpolyline(b, o.layer, color, o.points,
            closed: true, bulges: o.bulges);
      case DrawnType.text:
        if (o.points.isEmpty || (o.text ?? '').isEmpty) return const [];
        _text(b, o.layer, color, o.points.first,
            _escapeText(o.text!, _isOldFormat), textHeight, o.rotation);
      case DrawnType.dimension:
        if (o.points.length < 3) return const [];
        final layout = layoutDimension(
          o.points[0],
          o.points[1],
          o.points[2],
          textHeight: textHeight,
        );
        if (layout == null) return const [];
        _line(b, o.layer, color, o.points[0], layout.ext1End);
        _line(b, o.layer, color, o.points[1], layout.ext2End);
        _line(b, o.layer, color, layout.dimStart, layout.dimEnd);
        _arrow(b, o.layer, color, layout.dimStart, layout.dimEnd, textHeight);
        _arrow(b, o.layer, color, layout.dimEnd, layout.dimStart, textHeight);
        _text(
          b,
          o.layer,
          color,
          layout.textPosition,
          _escapeText(formatLength(layout.length, units), _isOldFormat),
          textHeight,
          layout.textAngleDeg,
        );
    }
    return b.isEmpty ? const [] : [b.toString()];
  }

  List<String> _entityForAnnotation(Annotation ann, double extent) {
    final r = math.max(extent / 300, 1e-3);
    final h = math.max(extent / 200, 1e-3);
    final b = StringBuffer();
    _entity(
        b, 'CIRCLE', 'AcDbCircle', kDxfPointsLayer, const _ColorCodes(aci: 1),
        (g) {
      _g(g, 10, _num(ann.dxfX));
      _g(g, 20, _num(ann.dxfY));
      _g(g, 30, '0.0');
      _g(g, 40, _num(r));
    });
    _text(
      b,
      kDxfPointsLayer,
      const _ColorCodes(aci: 7),
      Offset(ann.dxfX, ann.dxfY + r * 1.8),
      _escapeText('№${ann.number}', _isOldFormat),
      h,
      0,
    );
    return [b.toString()];
  }

  List<String> _entityForMeasurement(
      Measurement m, String units, double extent) {
    final h = math.max(extent / 200, 1e-3);
    const color = _ColorCodes(aci: 2);
    final b = StringBuffer();
    if (m is DistanceMeasurement) {
      _line(b, kDxfMeasurementsLayer, color, m.point1, m.point2);
      final mid = Offset(
        (m.point1.dx + m.point2.dx) / 2,
        (m.point1.dy + m.point2.dy) / 2,
      );
      _text(
        b,
        kDxfMeasurementsLayer,
        color,
        Offset(mid.dx, mid.dy + h * 1.5),
        _escapeText(m.formatResult(units).split('\n').first, _isOldFormat),
        h,
        0,
      );
    } else if (m is PolygonMeasurement && m.points.length >= 2) {
      _lwpolyline(b, kDxfMeasurementsLayer, color, m.points,
          closed: m.closed, bulges: const []);
      final last = m.points.last;
      _text(
        b,
        kDxfMeasurementsLayer,
        color,
        Offset(last.dx, last.dy - h * 1.5),
        _escapeText(m.formatResult(units).replaceAll('\n', ' '), _isOldFormat),
        h,
        0,
      );
    }
    return b.isEmpty ? const [] : [b.toString()];
  }

  // ---------- построение записей ----------

  String _num(double v) {
    if (!v.isFinite) return '0.0';
    var s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    if (s.isEmpty || s == '-') s = '0';
    return s;
  }

  void _g(StringBuffer b, int code, String value) {
    b.write(code.toString().padLeft(_codeWidth));
    b.write(_nl);
    // \U+XXXX — только для текстовых значений (код 1): AutoCAD понимает такие
    // эскейпы в тексте, но не в именах слоёв/таблиц (там «\» и «+» недопустимы).
    b.write(code == 1 ? _escapeNonAscii(value) : value);
    b.write(_nl);
  }

  /// Кириллица в текстовых значениях DXF: ASCII-эскейпы \U+XXXX, чтобы текст
  /// не зависел от $DWGCODEPAGE и AutoCAD показывал его корректно.
  String _escapeNonAscii(String s) {
    if (!s.runes.any((r) => r > 0x7F)) return s;
    final sb = StringBuffer();
    for (final rune in s.runes) {
      if (rune <= 0x7F) {
        sb.writeCharCode(rune);
      } else {
        sb.write(r'\U+');
        sb.write(rune.toRadixString(16).toUpperCase().padLeft(4, '0'));
      }
    }
    return sb.toString();
  }

  /// Заголовок сущности: для современного формата — handle, владелец,
  /// subclass-маркеры (без них AutoCAD считает файл повреждённым).
  void _entity(
    StringBuffer b,
    String type,
    String modernSubclass,
    String layer,
    _ColorCodes color,
    void Function(StringBuffer) body,
  ) {
    _g(b, 0, type);
    if (_modern) {
      _g(b, 5, _handleGen.next());
      if (_ownerHandle != null) _g(b, 330, _ownerHandle!);
      _g(b, 100, 'AcDbEntity');
    }
    _g(b, 8, layer);
    if (color.aci != null) _g(b, 62, '${color.aci}');
    if (color.rgb != null) _g(b, 420, '${color.rgb}');
    if (_modern) _g(b, 100, modernSubclass);
    body(b);
  }

  void _line(
    StringBuffer b,
    String layer,
    _ColorCodes color,
    Offset a,
    Offset c,
  ) {
    _entity(b, 'LINE', 'AcDbLine', layer, color, (g) {
      _g(g, 10, _num(a.dx));
      _g(g, 20, _num(a.dy));
      _g(g, 30, '0.0');
      _g(g, 11, _num(c.dx));
      _g(g, 21, _num(c.dy));
      _g(g, 31, '0.0');
    });
  }

  void _lwpolyline(
    StringBuffer b,
    String layer,
    _ColorCodes color,
    List<Offset> points, {
    required bool closed,
    required List<double> bulges,
  }) {
    _entity(b, 'LWPOLYLINE', 'AcDbPolyline', layer, color, (g) {
      _g(g, 90, '${points.length}');
      _g(g, 70, closed ? '1' : '0');
      for (var i = 0; i < points.length; i++) {
        _g(g, 10, _num(points[i].dx));
        _g(g, 20, _num(points[i].dy));
        final bulge = i < bulges.length ? bulges[i] : 0.0;
        if (bulge.abs() > 1e-12) _g(g, 42, _num(bulge));
      }
    });
  }

  void _text(
    StringBuffer b,
    String layer,
    _ColorCodes color,
    Offset pos,
    String content,
    double height,
    double rotation,
  ) {
    _entity(b, 'TEXT', 'AcDbText', layer, color, (g) {
      _g(g, 10, _num(pos.dx));
      _g(g, 20, _num(pos.dy));
      _g(g, 30, '0.0');
      _g(g, 40, _num(height));
      _g(g, 1, content);
      if (rotation.abs() > 1e-9) _g(g, 50, _num(rotation));
      // Центрирование по точке (приложение рисует текст по центру).
      _g(g, 72, '1');
      _g(g, 11, _num(pos.dx));
      _g(g, 21, _num(pos.dy));
      _g(g, 31, '0.0');
      // В современном DXF у TEXT второй subclass-маркер AcDbText:
      // без него AutoCAD падает с «Неожиданный код группы 73».
      if (_modern) _g(g, 100, 'AcDbText');
      _g(g, 73, '2');
    });
  }

  void _arrow(
    StringBuffer b,
    String layer,
    _ColorCodes color,
    Offset tip,
    Offset towards,
    double textHeight,
  ) {
    final d = towards - tip;
    final len = d.distance;
    if (len < 1e-9) return;
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    final l = textHeight * 0.9;
    final w = textHeight * 0.28;
    final base = tip + u * l;
    final p1 = base + n * w;
    final p2 = base - n * w;
    _entity(b, 'SOLID', 'AcDbTrace', layer, color, (g) {
      _g(g, 10, _num(tip.dx));
      _g(g, 20, _num(tip.dy));
      _g(g, 30, '0.0');
      _g(g, 11, _num(p1.dx));
      _g(g, 21, _num(p1.dy));
      _g(g, 31, '0.0');
      _g(g, 12, _num(p2.dx));
      _g(g, 22, _num(p2.dy));
      _g(g, 32, '0.0');
      _g(g, 13, _num(p2.dx));
      _g(g, 23, _num(p2.dy));
      _g(g, 33, '0.0');
    });
  }

  // ---------- слои ----------

  String _buildLayerBlock(_Source src, Set<String> layers) {
    final missing = [
      for (final name in layers)
        if (!src.existingLayers.contains(name)) name,
    ]..sort();
    final b = StringBuffer();
    for (final name in missing) {
      _g(b, 0, 'LAYER');
      if (_modern) {
        _g(b, 5, _handleGen.next());
        if (_layerTableHandle != null) _g(b, 330, _layerTableHandle!);
        _g(b, 100, 'AcDbSymbolTableRecord');
        _g(b, 100, 'AcDbLayerTableRecord');
      }
      _g(b, 2, name);
      _g(b, 70, '0');
      _g(b, 62, '7');
      // Коды 6/370/390/347/348 копируем у существующего слоя: без 390
      // (стиль печати) AutoCAD отказывается импортировать LAYER-таблицу.
      if (src.layerTail.isNotEmpty) {
        for (final (code, value) in src.layerTail) {
          _g(b, code, value);
        }
      } else {
        _g(b, 6, 'CONTINUOUS');
      }
    }
    return b.toString();
  }

  // ---------- CSV/README ----------

  String _buildPointsCsv(
    List<Annotation> annotations,
    Map<String, List<String>> photoNames,
  ) {
    final b = StringBuffer();
    // Единая система координат — совпадает с DXF: X/Y точки и высота Z.
    b.writeln('Номер;X;Y;Z;Код;Описание;Фото;Дата');
    for (final ann in annotations) {
      final row = [
        ann.number.toString(),
        ann.dxfX.toStringAsFixed(3),
        ann.dxfY.toStringAsFixed(3),
        ann.geoZ?.toStringAsFixed(3) ?? '',
        ann.code ?? '',
        _escapeCsv(ann.description ?? ''),
        (photoNames[ann.id] ?? const []).join('|'),
        _formatDate(ann.createdAt),
      ];
      b.writeln(row.join(';'));
    }
    return b.toString();
  }

  String _buildReadme(String drawingName, int points) {
    return 'Мензулка — экспорт «DXF + фото»\n'
        '========================================\n\n'
        'Чертёж: $drawingName\n'
        'Точек: $points\n\n'
        'Состав архива:\n'
        '  - <имя>.dxf — чертёж (все исходные примитивы + нарисованные объекты\n'
        '    по слоям + точки/измерения, если включены);\n'
        '  - photos/ — фотографии точек (имя: <номер точки>_<id>.<ext>), они\n'
        '    привязаны к точкам, а не геопривязаны в чертеже;\n'
        '  - points.csv — список точек: номера, координаты X/Y/Z (в системе\n'
        '    чертежа, совпадает с DXF), коды, описания, файлы фото (через «|», если их несколько);\n'
        '  - README.txt — этот файл.\n\n'
        'Фотографии в сам DXF не встраиваются: DXF — формат геометрии, а снимки\n'
        'не имеют привязки к мировым координатам. Для переноса проекта целиком\n'
        '(чертёж + точки + фото + голосовые заметки) используйте .abris.\n';
  }

  String _escapeCsv(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _sanitizeFileName(String name) {
    // Имя файла — без исходного расширения (.bin/.dxf): экспорт «имя.dxf»/«имя.zip».
    final cleaned = p
        .basenameWithoutExtension(name)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'dxf_export' : cleaned;
  }

  String _escapeText(String text, bool oldFormat) {
    final oneLine = text.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (!oldFormat) return oneLine;
    final b = StringBuffer();
    for (final rune in oneLine.runes) {
      if (rune < 0x80) {
        b.writeCharCode(rune);
      } else {
        b.write('\\U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}');
      }
    }
    return b.toString();
  }

  Future<String> exportToFile(
    String drawingId,
    DxfExportOptions options, {
    String? outputDirectory,
    void Function(int done, int total)? onProgress,
  }) async {
    final drawing = await _db.getDrawingById(drawingId);
    if (drawing == null) throw StateError('Чертёж не найден');
    final Uint8List data;
    final String extension;
    final bool isDwg = options.dwgVersion != null;
    if (options.mode == DxfExportMode.withPhotos) {
      data = await buildZipBytes(drawingId, options, onProgress: onProgress);
      extension = 'zip';
    } else if (isDwg) {
      final dxf = await buildDxfBytes(drawingId, options);
      data = await CadConverter.dxfToDwg(dxf, version: options.dwgVersion!);
      extension = 'dwg';
    } else {
      data = await buildDxfBytes(drawingId, options);
      extension = 'dxf';
    }
    final dir = outputDirectory != null
        ? Directory(outputDirectory)
        : await _exportsDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final base = _sanitizeFileName(drawing.name);
    var target = p.join(dir.path, '$base.$extension');
    var counter = 1;
    while (await File(target).exists()) {
      target = p.join(dir.path, '${base}_$counter.$extension');
      counter++;
    }
    await File(target).writeAsBytes(data);
    final String summary;
    final String eventType;
    if (options.mode == DxfExportMode.withPhotos) {
      summary = 'DXF + фото (ZIP) экспортирован, ${formatBytes(data.length)}';
      eventType = HistoryEventType.dxfExported;
    } else if (isDwg) {
      summary = 'DWG ${options.dwgVersion!.label} экспортирован, '
          '${formatBytes(data.length)}';
      eventType = HistoryEventType.dwgExported;
    } else {
      summary = 'DXF экспортирован, ${formatBytes(data.length)}';
      eventType = HistoryEventType.dxfExported;
    }
    await _db.logEvent(
      drawingId: drawingId,
      type: eventType,
      summary: summary,
    );
    return target;
  }

  Future<Directory> _exportsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

/// ACI/RGB для новых сущностей.
class _ColorCodes {
  final int? aci;
  final int? rgb;
  const _ColorCodes({this.aci, this.rgb});
}

const Map<int, List<int>> _aciPalette = {
  1: [255, 0, 0],
  2: [255, 255, 0],
  3: [0, 255, 0],
  4: [0, 255, 255],
  5: [0, 0, 255],
  6: [255, 0, 255],
  7: [255, 255, 255],
  30: [255, 127, 0],
};

int _aciForColor(int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  var best = 7;
  var bestD = double.infinity;
  for (final entry in _aciPalette.entries) {
    final dr = (r - entry.value[0]).toDouble();
    final dg = (g - entry.value[1]).toDouble();
    final db = (b - entry.value[2]).toDouble();
    final d = dr * dr + dg * dg + db * db;
    if (d < bestD) {
      bestD = d;
      best = entry.key;
    }
  }
  return best;
}

_ColorCodes _colorCodes(int argb) {
  final aci = _aciForColor(argb);
  if (aci == 7) return const _ColorCodes(aci: 7);
  return _ColorCodes(aci: aci, rgb: argb & 0xFFFFFF);
}

/// Генератор handle-ов (hex), начиная после максимального в исходнике.
class _HandleGen {
  int _next;
  _HandleGen(int maxHandle) : _next = maxHandle + 1;

  String next() => (_next++).toRadixString(16).toUpperCase();

  String peek() => _next.toRadixString(16).toUpperCase();
}

/// Правка исходника: вставка ([remove] == 0) или замена.
class _Edit {
  final int offset;
  final List<int> data;
  final int remove;
  _Edit(this.offset, this.data, {this.remove = 0});
}

/// Границы чертежа для $EXTMIN/$EXTMAX.
class _Extents {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  const _Extents(this.minX, this.minY, this.maxX, this.maxY);
}

/// Исходный DXF: индексация строк/пар и побайтовое редактирование.
class _Source {
  _Source(this.bytes) {
    _buildLines();
    _buildPairs();
    _detectStyle();
    _findSections();
    _detectVersion();
    _parseHandles();
  }

  final Uint8List bytes;
  final List<_SrcLine> _lines = [];
  final List<_Pair> _pairs = [];
  String _nl = '\n';
  int _codeWidth = 3;

  final Set<String> existingLayers = {};

  _Section? _entities;
  _Section? _tables;
  _Table? _layerTable;
  _Section? _header;

  int maxHandle = 0;
  String? modelSpaceHandle;
  String? layerTableHandle;
  (int, int)? _handSeedValue;
  final List<(int, int)> _extMinValues = [];
  final List<(int, int)> _extMaxValues = [];
  final List<String> _extMinTexts = [];
  final List<String> _extMaxTexts = [];

  /// Версия формата из $ACADVER (например, 1032).
  int? acadVersion;

  /// Хвост существующего слоя (6/370/390/347/348): стиль печати (390)
  /// обязателен для AutoCAD, иначе импорт падает с «Ошибка в таблице LAYER».
  final List<(int, String)> layerTail = [];

  int get codeWidth => _codeWidth;
  String get nl => _nl;
  bool get isModern => acadVersion == null || acadVersion! >= 1012;
  bool get isOldFormat => acadVersion != null && acadVersion! < 1021;

  void _buildLines() {
    var start = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) {
        var contentEnd = i;
        if (contentEnd > start && bytes[contentEnd - 1] == 0x0D) {
          contentEnd--;
        }
        final raw = utf8.decode(Uint8List.sublistView(bytes, start, contentEnd),
            allowMalformed: true);
        _lines.add(_SrcLine(start, i + 1, raw));
        start = i + 1;
      }
    }
    if (start < bytes.length) {
      final raw = utf8.decode(Uint8List.sublistView(bytes, start),
          allowMalformed: true);
      _lines.add(_SrcLine(start, bytes.length, raw));
    }
  }

  void _buildPairs() {
    var i = 0;
    while (i + 1 < _lines.length) {
      final code = int.tryParse(_lines[i].raw.trim());
      if (code == null) {
        i++;
        continue;
      }
      final valueLine = _lines[i + 1];
      final valueStart = valueLine.start;
      final valueEnd = valueStart + utf8.encode(valueLine.raw).length;
      _pairs.add(_Pair(
        code,
        valueLine.raw.trim(),
        _lines[i].start,
        valueLine.end,
        valueStart,
        valueEnd,
      ));
      i += 2;
    }
  }

  void _detectStyle() {
    for (final line in _lines) {
      final raw = line.raw;
      if (raw.trim().isEmpty) continue;
      if (int.tryParse(raw.trim()) != null) {
        _codeWidth = raw.length;
        break;
      }
    }
    if (_codeWidth <= 0) _codeWidth = 3;
    if (_lines.isNotEmpty &&
        _lines.first.end >= 2 &&
        bytes[_lines.first.end - 2] == 0x0D) {
      _nl = '\r\n';
    }
  }

  void _findSections() {
    for (var i = 0; i < _pairs.length; i++) {
      final pr = _pairs[i];
      if (pr.code == 0 && pr.value == 'SECTION') {
        final namePr = i + 1 < _pairs.length ? _pairs[i + 1] : null;
        if (namePr != null && namePr.code == 2) {
          final endIdx = _findEndsec(i + 1);
          if (endIdx < 0) continue;
          final section =
              _Section(namePr.value, startPair: i, endsecPair: endIdx);
          switch (namePr.value) {
            case 'ENTITIES':
              _entities = section;
            case 'TABLES':
              _tables = section;
            case 'HEADER':
              _header = section;
          }
        }
      }
    }
    final tables = _tables;
    if (tables != null) {
      for (var i = tables.startPair + 2; i < tables.endsecPair; i++) {
        final pr = _pairs[i];
        if (pr.code == 0 && pr.value == 'TABLE') {
          final namePr = i + 1 < _pairs.length ? _pairs[i + 1] : null;
          if (namePr != null && namePr.code == 2) {
            if (namePr.value == 'LAYER') {
              final endtab = _findEndtab(i);
              if (endtab > 0) {
                _layerTable = _Table(startPair: i, endtabPair: endtab);
                _collectLayerNames(i, endtab);
                layerTableHandle = _findHandleIn(i, endtab);
              }
            } else if (namePr.value == 'BLOCK_RECORD') {
              _parseModelSpaceHandle(i);
            }
          }
        }
      }
    }
    // $HANDSEED и границы чертежа из HEADER.
    final header = _header;
    if (header != null) {
      for (var i = header.startPair; i + 1 < header.endsecPair; i++) {
        final pr = _pairs[i];
        if (pr.code == 9 && pr.value == '\$HANDSEED') {
          final v = _pairs[i + 1];
          if (v.code == 5) _handSeedValue = (v.valueStart, v.valueEnd);
        }
        if (pr.code == 9 &&
            (pr.value == '\$EXTMIN' || pr.value == '\$EXTMAX')) {
          final vals = <(int, int)>[];
          final values = <String>[];
          var j = i + 1;
          while (j < header.endsecPair && vals.length < 3) {
            final pj = _pairs[j];
            if (pj.code == 10 || pj.code == 20 || pj.code == 30) {
              vals.add((pj.valueStart, pj.valueEnd));
              values.add(pj.value);
            } else if (pj.code == 9) {
              break;
            }
            j++;
          }
          if (vals.length == 3) {
            if (pr.value == '\$EXTMIN') {
              _extMinValues.addAll(vals);
              _extMinTexts.addAll(values);
            } else {
              _extMaxValues.addAll(vals);
              _extMaxTexts.addAll(values);
            }
          }
        }
      }
    }
  }

  void _parseModelSpaceHandle(int tableStart) {
    var i = tableStart + 2;
    while (i < _pairs.length) {
      final pr = _pairs[i];
      if (pr.code == 0 && pr.value == 'ENDTAB') break;
      if (pr.code == 0 && pr.value == 'BLOCK_RECORD') {
        String? name;
        String? handle;
        var j = i + 1;
        while (j < _pairs.length && !(_pairs[j].code == 0)) {
          final pj = _pairs[j];
          if (pj.code == 2) name = pj.value;
          if (pj.code == 5) handle = pj.value;
          j++;
        }
        if (name == '*Model_Space' && handle != null) {
          modelSpaceHandle = handle;
          return;
        }
        i = j;
        continue;
      }
      i++;
    }
  }

  String? _findHandleIn(int fromPair, int endtabPair) {
    for (var i = fromPair + 1; i < endtabPair; i++) {
      if (_pairs[i].code == 5) return _pairs[i].value;
    }
    return null;
  }

  void _parseHandles() {
    for (final pr in _pairs) {
      if (pr.code == 5) {
        final v = int.tryParse(pr.value, radix: 16);
        if (v != null && v > maxHandle) maxHandle = v;
      }
    }
  }

  int _findEndsec(int fromPair) {
    for (var i = fromPair + 1; i < _pairs.length; i++) {
      final pr = _pairs[i];
      if (pr.code == 0 && pr.value == 'ENDSEC') return i;
    }
    return -1;
  }

  int _findEndtab(int fromPair) {
    for (var i = fromPair + 1; i < _pairs.length; i++) {
      final pr = _pairs[i];
      if (pr.code == 0 && pr.value == 'ENDTAB') return i;
      if (pr.code == 0 && pr.value == 'TABLE') return -1;
    }
    return -1;
  }

  void _collectLayerNames(int fromPair, int endtabPair) {
    for (var i = fromPair + 2; i < endtabPair; i++) {
      final pr = _pairs[i];
      if (pr.code == 0 && pr.value == 'LAYER') {
        final namePr = i + 1 < _pairs.length ? _pairs[i + 1] : null;
        if (namePr != null && namePr.code == 2) {
          existingLayers.add(namePr.value);
        }
        if (layerTail.isEmpty) _collectLayerTail(i);
      }
    }
  }

  void _detectVersion() {
    final header = _header;
    if (header == null) return;
    for (var i = header.startPair; i < header.endsecPair; i++) {
      final pr = _pairs[i];
      if (pr.code == 9 && pr.value == '\$ACADVER') {
        for (var j = i + 1; j < header.endsecPair; j++) {
          final v = _pairs[j];
          if (v.code == 1) {
            final m = RegExp(r'AC(\d{4})').firstMatch(v.value);
            if (m != null) acadVersion = int.tryParse(m.group(1)!);
            return;
          }
        }
      }
    }
  }

  /// Собирает хвост первого слоя (линетип/вес/стиль печати/материал).
  void _collectLayerTail(int layerStart) {
    var i = layerStart + 1;
    while (i < _pairs.length && _pairs[i].code != 0) {
      final pr = _pairs[i];
      if (pr.code == 6 ||
          pr.code == 370 ||
          pr.code == 390 ||
          pr.code == 347 ||
          pr.code == 348) {
        layerTail.add((pr.code, pr.value));
      }
      i++;
    }
  }

  /// Нужно ли править $EXTMIN/$EXTMAX: только если в исходнике они «пустые»
  /// (1e+20), нечисловые или перевёрнутые. Нормальные чертежи не трогаем —
  /// заголовок остаётся байт-в-байт, и AutoCAD не спотыкается на нём.
  bool get extentsNeedFix {
    if (_extMinTexts.length != 3 || _extMaxTexts.length != 3) return true;
    final nums = <double>[];
    for (final s in [..._extMinTexts, ..._extMaxTexts]) {
      final v = double.tryParse(s);
      if (v == null || !v.isFinite) return true;
      if (v.abs() > 1e14) return true;
      nums.add(v);
    }
    if (nums.length != 6) return true;
    if (nums[0] > nums[3] || nums[1] > nums[4]) return true;
    return false;
  }

  /// Вставляет блок слоёв и сущностей, обновляет $HANDSEED и границы.
  Uint8List inject(String layerBlock, String entityBlock,
      {String? newHandSeed, _Extents? extents}) {
    final edits = <_Edit>[];
    if (layerBlock.isNotEmpty) {
      // Имена слоёв пишем как есть (UTF-8): \U+XXXX в именах таблиц AutoCAD
      // считает недопустимыми символами и отказывается открывать файл.
      edits.add(_Edit(
        _layerInsertOffset(),
        utf8.encode(_wrapLayers(layerBlock)),
      ));
    }
    if (entityBlock.isNotEmpty && _entities != null) {
      // Текстовые значения (код 1) уже экранированы в _g; имена слоёв (8) —
      // raw UTF-8, чтобы совпадать с LAYER-таблицей.
      edits.add(_Edit(
        _pairs[_entities!.endsecPair].start,
        utf8.encode(entityBlock),
      ));
    }
    final seed = _handSeedValue;
    if (newHandSeed != null && seed != null) {
      edits.add(
          _Edit(seed.$1, utf8.encode(newHandSeed), remove: seed.$2 - seed.$1));
    }
    if (extents != null && extentsNeedFix) {
      _addExtentEdit(edits, _extMinValues, [extents.minX, extents.minY, 0.0]);
      _addExtentEdit(edits, _extMaxValues, [extents.maxX, extents.maxY, 0.0]);
    }
    return _applyEdits(bytes, edits);
  }

  void _addExtentEdit(
      List<_Edit> edits, List<(int, int)> values, List<double> newValues) {
    if (values.length != 3) return;
    for (var i = 0; i < 3; i++) {
      final v = values[i];
      edits.add(
          _Edit(v.$1, utf8.encode(_fmt(newValues[i])), remove: v.$2 - v.$1));
    }
  }

  String _fmt(double v) {
    if (!v.isFinite || v.abs() > 1e15) return '0.0';
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = '${s}0';
    }
    if (!s.contains('.')) s = '$s.0';
    return s;
  }

  Uint8List _applyEdits(Uint8List src, List<_Edit> edits) {
    if (edits.isEmpty) return src;
    edits.sort((a, b) => a.offset.compareTo(b.offset));
    final out = BytesBuilder(copy: false);
    var pos = 0;
    for (final e in edits) {
      if (e.offset > pos) out.add(src.sublist(pos, e.offset));
      out.add(e.data);
      pos = e.offset + e.remove;
    }
    if (pos < src.length) out.add(src.sublist(pos));
    return out.toBytes();
  }

  String _wrapLayers(String entries) {
    if (_layerTable != null) return entries;
    final table = _rawCode(0, 'TABLE') +
        _rawCode(2, 'LAYER') +
        _rawCode(70, '1') +
        entries +
        _rawCode(0, 'ENDTAB');
    if (_tables != null) return table;
    return _rawCode(0, 'SECTION') +
        _rawCode(2, 'TABLES') +
        table +
        _rawCode(0, 'ENDSEC');
  }

  int _layerInsertOffset() {
    final table = _layerTable;
    if (table != null) return _pairs[table.endtabPair].start;
    final tables = _tables;
    if (tables != null) return _pairs[tables.endsecPair].start;
    final header = _header;
    if (header != null) return _pairs[header.endsecPair].end;
    final entities = _entities;
    if (entities != null) return _pairs[entities.startPair].start;
    return bytes.length;
  }

  String _rawCode(int code, String value) =>
      '${code.toString().padLeft(_codeWidth)}$_nl$value$_nl';
}

class _SrcLine {
  final int start;
  final int end;
  final String raw;
  _SrcLine(this.start, this.end, this.raw);
}

class _Pair {
  final int code;
  final String value;
  final int start;
  final int end;
  final int valueStart;
  final int valueEnd;
  _Pair(this.code, this.value, this.start, this.end, this.valueStart,
      this.valueEnd);
}

class _Section {
  final String name;
  final int startPair;
  final int endsecPair;
  _Section(this.name, {required this.startPair, required this.endsecPair});
}

class _Table {
  final int startPair;
  final int endtabPair;
  _Table({required this.startPair, required this.endtabPair});
}
