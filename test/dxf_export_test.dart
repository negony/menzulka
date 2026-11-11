import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/exporters/dxf_exporter.dart';
import 'package:menzulka/models/annotation.dart';
import 'package:menzulka/models/drawn_object.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/models/measurement.dart';
import 'package:menzulka/models/photo.dart';
import 'package:menzulka/services/dxf_parser.dart';
import 'package:menzulka/services/project_bundle.dart' show ExportPhotoQuality;
import 'package:menzulka/utils/drawn_geometry.dart';

/// Собирает маленький DXF в стиле AutoCAD (пара «код/значение»).
String _dxf(
  String extraEntities, {
  String version = 'AC1032',
  bool withLayerTable = true,
  bool crlf = false,
  bool padCodes = true,
}) {
  if (crlf) {
    return _dxf(extraEntities,
            version: version,
            withLayerTable: withLayerTable,
            crlf: false,
            padCodes: padCodes)
        .replaceAll('\n', '\r\n');
  }
  String c(int code, String v) =>
      '${padCodes ? code.toString().padLeft(3) : '$code'}\n$v\n';
  final b = StringBuffer();
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'HEADER'));
  b.write(c(9, r'$ACADVER'));
  b.write(c(1, version));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'TABLES'));
  if (withLayerTable) {
    b.write(c(0, 'TABLE'));
    b.write(c(2, 'LAYER'));
    b.write(c(70, '1'));
    b.write(c(0, 'LAYER'));
    b.write(c(2, '0'));
    b.write(c(70, '0'));
    b.write(c(62, '7'));
    b.write(c(6, 'CONTINUOUS'));
    b.write(c(0, 'ENDTAB'));
  }
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'ENTITIES'));
  b.write(c(0, 'LINE'));
  b.write(c(8, '0'));
  b.write(c(10, '0'));
  b.write(c(20, '0'));
  b.write(c(11, '10'));
  b.write(c(21, '0'));
  b.write(extraEntities);
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'EOF'));
  return b.toString();
}

const String kHatch = '  0\nHATCH\n  8\n0\n  2\nSOLID\n 70\n0\n';

/// Минимальный, но структурно корректный современный DXF (AC1032):
/// TABLES с LAYER/BLOCK_RECORD, $HANDSEED, ENTITIES с handle/subclass.
String _dxfModern() {
  String c(int code, String v) => '${code.toString().padLeft(3)}\n$v\n';
  final b = StringBuffer();
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'HEADER'));
  b.write(c(9, r'$ACADVER'));
  b.write(c(1, 'AC1032'));
  b.write(c(9, r'$HANDSEED'));
  b.write(c(5, '200'));
  b.write(c(9, r'$EXTMIN'));
  b.write(c(10, '1e+20'));
  b.write(c(20, '1e+20'));
  b.write(c(30, '1e+20'));
  b.write(c(9, r'$EXTMAX'));
  b.write(c(10, '-1e+20'));
  b.write(c(20, '-1e+20'));
  b.write(c(30, '-1e+20'));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'TABLES'));
  b.write(c(0, 'TABLE'));
  b.write(c(2, 'LAYER'));
  b.write(c(5, '2'));
  b.write(c(70, '1'));
  b.write(c(0, 'LAYER'));
  b.write(c(5, '10'));
  b.write(c(330, '2'));
  b.write(c(100, 'AcDbSymbolTableRecord'));
  b.write(c(100, 'AcDbLayerTableRecord'));
  b.write(c(2, '0'));
  b.write(c(70, '0'));
  b.write(c(62, '7'));
  b.write(c(6, 'CONTINUOUS'));
  b.write(c(370, '-3'));
  b.write(c(390, 'F'));
  b.write(c(347, 'EE'));
  b.write(c(0, 'ENDTAB'));
  b.write(c(0, 'TABLE'));
  b.write(c(2, 'BLOCK_RECORD'));
  b.write(c(5, '1'));
  b.write(c(70, '1'));
  b.write(c(0, 'BLOCK_RECORD'));
  b.write(c(5, '1F'));
  b.write(c(330, '1'));
  b.write(c(100, 'AcDbSymbolTableRecord'));
  b.write(c(100, 'AcDbBlockTableRecord'));
  b.write(c(2, '*Model_Space'));
  b.write(c(0, 'ENDTAB'));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'ENTITIES'));
  b.write(c(0, 'LINE'));
  b.write(c(5, '20'));
  b.write(c(330, '1F'));
  b.write(c(100, 'AcDbEntity'));
  b.write(c(8, '0'));
  b.write(c(100, 'AcDbLine'));
  b.write(c(10, '0'));
  b.write(c(20, '0'));
  b.write(c(30, '0'));
  b.write(c(11, '10'));
  b.write(c(21, '0'));
  b.write(c(31, '0'));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'EOF'));
  return b.toString();
}

DrawnObject _o(
  DrawnType type,
  List<Offset> points, {
  String layer = 'Слой 1',
  List<double> bulges = const [],
  String? text,
  double? height,
  double rotation = 0,
  int color = kDrawnDefaultColor,
}) {
  return DrawnObject(
    id: type.name,
    drawingId: 'd1',
    type: type,
    points: points,
    bulges: bulges,
    text: text,
    height: height,
    rotation: rotation,
    color: color,
    layer: layer,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<DxfDocument> _parseOut(Uint8List bytes) => DxfParser().parseBytes(bytes);

Uint8List _export(
  String original, {
  List<DrawnObject> objects = const [],
  List<Annotation> annotations = const [],
  List<Measurement> measurements = const [],
  DxfExportOptions options = const DxfExportOptions(
    includePoints: false,
    includeMeasurements: false,
  ),
  String units = 'm',
}) {
  return _service.buildFromParts(
    originalBytes: Uint8List.fromList(utf8.encode(original)),
    document: _lastDoc!,
    drawnObjects: objects,
    annotations: annotations,
    measurements: measurements,
    options: options,
    units: units,
    drawingName: 'test',
  );
}

DxfDocument? _lastDoc;
final _service = DxfExportService();

void main() {
  test('исходные примитивы сохраняются, новые добавляются, слой в таблице',
      () async {
    final src = _dxf(kHatch);
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _export(
      src,
      objects: [
        _o(DrawnType.line, const [Offset(1, 1), Offset(5, 5)]),
        _o(DrawnType.circle, const [Offset(3, 3), Offset(4, 3)]),
      ],
    );
    final outStr = utf8.decode(out);
    // Оригинальные записи на месте, включая неподдерживаемый HATCH.
    expect(outStr, contains('HATCH'));
    expect(outStr, contains('LINE'));
    expect(outStr.split('ENDSEC').length, greaterThan(3));
    // Слой добавлен в таблицу LAYER.
    expect(outStr, contains('LAYER'));
    final parsed = await _parseOut(out);
    final layerNames = parsed.layers.map((l) => l.name).toList();
    expect(layerNames, contains('Слой 1'));
    expect(parsed.entities.whereType<DxfCircle>().length, 1);
    final lines = parsed.entities.whereType<DxfLine>().toList();
    // исходный отрезок + нарисованный
    expect(lines.length, 2);
    expect(parsed.entities.any((e) => e.layer == 'Слой 1'), isTrue);
  });

  test(
      'имена слоёв пишутся как есть (UTF-8), без \\U+ — иначе AutoCAD '
      'считает имя таблицы недопустимым', () async {
    final src = _dxfModern();
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _export(
      src,
      objects: [
        _o(DrawnType.line, const [Offset(1, 1), Offset(5, 5)], layer: 'Слой 1'),
        _o(DrawnType.text, const [Offset(2, 2)],
            text: 'ТОЧКА', height: 1.5, layer: 'Слой 1'),
      ],
    );
    final outStr = utf8.decode(out);
    // Имя слоя — raw UTF-8 (совпадает в LAYER-таблице и в сущностях),
    // \U+-эскейпов в именах таблиц быть не должно.
    expect(outStr, contains('Слой 1'));
    expect(outStr, isNot(contains(r'\U+0421')));
    expect(outStr, isNot(contains(r'\U+0442')));
    // Текст (код 1) по-прежнему эскейпится — это допустимо и не ломает файл.
    expect(outStr, contains(r'\U+0422\U+041E\U+0427\U+041A\U+0410'));
    final parsed = await _parseOut(out);
    expect(parsed.layers.map((l) => l.name), contains('Слой 1'));
    // Обязательный слой «0» остаётся в таблице.
    expect(parsed.layers.map((l) => l.name), contains('0'));
    expect(parsed.entities.any((e) => e.layer == 'Слой 1'), isTrue);
  });

  test('эталонный пустой DXF (assets/empty.dxf) — парсится и экспортируется',
      () async {
    final bytes = File('assets/empty.dxf').readAsBytesSync();
    final doc = await DxfParser().parseBytes(Uint8List.fromList(bytes));
    expect(doc.entities, isEmpty);
    expect(doc.layers.map((l) => l.name), contains('0'));
    // Эталон проходит через экспорт и остаётся структурно корректным.
    _lastDoc = doc;
    final out = _service.buildFromParts(
      originalBytes: Uint8List.fromList(bytes),
      document: doc,
      drawnObjects: [
        _o(DrawnType.point, const [Offset(3, 3)], layer: 'Слой 1'),
      ],
      annotations: const [],
      measurements: const [],
      options: const DxfExportOptions(
        includePoints: false,
        includeMeasurements: false,
      ),
      units: 'm',
      drawingName: 'test',
    );
    final parsed = await _parseOut(out);
    expect(parsed.layers.map((l) => l.name), containsAll(['0', 'Слой 1']));
    final outStr = utf8.decode(out);
    expect(outStr, contains('Слой 1'));
    // Имя слоя — как есть (UTF-8), без \U+ — иначе AutoCAD не откроет файл.
    expect(outStr, isNot(contains(r'\U+0421')));
    // Все обязательные таблицы AutoCAD на месте (иначе «Ошибка в таблице APPID»).
    for (final table in [
      'VPORT',
      'LTYPE',
      'LAYER',
      'STYLE',
      'VIEW',
      'UCS',
      'APPID',
      'DIMSTYLE',
      'BLOCK_RECORD',
    ]) {
      expect(outStr, contains(table), reason: 'нет таблицы $table');
    }
  });

  test('round-trip всех типов нарисованного', () async {
    final src = _dxf('');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final cloud = buildCloud(
        rectangleCorners(const Offset(20, 20), const Offset(30, 26)));
    final objects = <DrawnObject>[
      _o(DrawnType.point, const [Offset(1, 1)], layer: 'Слой 1'),
      _o(DrawnType.polyline, const [Offset(2, 2), Offset(4, 2), Offset(4, 4)]),
      _o(DrawnType.line, const [Offset(0, 5), Offset(5, 5)]),
      _o(DrawnType.ray, const [Offset(8, 8), Offset(9, 9)]),
      _o(DrawnType.circle, const [Offset(10, 10), Offset(12, 10)]),
      _o(DrawnType.rectangle,
          rectangleCorners(const Offset(15, 15), const Offset(19, 18))),
      _o(DrawnType.cloud, cloud.vertices, bulges: cloud.bulges),
      _o(DrawnType.text, const [Offset(40, 40)],
          text: 'ПРИВЕТ', height: 2.0, rotation: 30),
      _o(DrawnType.dimension,
          const [Offset(50, 0), Offset(55, 0), Offset(50, 3)],
          height: 1.5, layer: 'Слой 2'),
    ];
    final out = _export(src, objects: objects, units: 'm');
    final parsed = await _parseOut(out);

    expect(parsed.layers.map((l) => l.name), containsAll(['Слой 1', 'Слой 2']));
    expect(parsed.entities.whereType<DxfPoint>().length, 1);
    expect(parsed.entities.whereType<DxfRay>().length, 1);
    expect(parsed.entities.whereType<DxfCircle>().length, 1);
    final polylines = parsed.entities.whereType<DxfLwPolyline>().toList();
    // полилиния, прямоугольник, облако
    expect(polylines.length, 3);
    final rect =
        polylines.firstWhere((p) => p.isClosed && p.vertices.length == 4);
    expect(rect.vertices.length, 4);
    final cloudOut = polylines.firstWhere((p) => p.vertices.length > 4);
    expect(cloudOut.isClosed, isTrue);
    expect(cloudOut.vertices.any((v) => v.bulge.abs() > 0.5), isTrue);
    // Текст: содержимое/высота/поворот.
    final texts = parsed.entities.whereType<DxfText>().toList();
    final title = texts.firstWhere((t) => t.content.contains('ПРИВЕТ'));
    expect(title.height, closeTo(2.0, 1e-6));
    expect(title.rotation, closeTo(30, 1e-6));
    // Размер: выносные + размерная линия + стрелки + текст.
    final dimText = texts.where((t) => t.content.contains('м')).toList();
    expect(dimText, isNotEmpty);
    // Цвет сохраняется (true color).
    final point = parsed.entities.whereType<DxfPoint>().first;
    expect(point.trueColor, isNotNull);
    expect(point.trueColor! & 0xFFFFFF, kDrawnDefaultColor & 0xFFFFFF);
  });

  test('без таблицы LAYER создаётся TABLE/LAYER', () async {
    final src = _dxf('', withLayerTable: false);
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _export(src, objects: [
      _o(DrawnType.point, const [Offset(3, 3)], layer: 'Новый слой'),
    ]);
    final parsed = await _parseOut(out);
    expect(parsed.layers.map((l) => l.name), contains('Новый слой'));
    expect(parsed.entities.whereType<DxfPoint>().length, 1);
  });

  test('дубликат слоя не добавляется', () async {
    final src = _dxf('');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _export(src, objects: [
      _o(DrawnType.point, const [Offset(3, 3)], layer: '0'),
    ]);
    final parsed = await _parseOut(out);
    expect(parsed.layers.where((l) => l.name == '0').length, 1);
    expect(parsed.layers.length, 1);
  });

  test('опции точек и измерений: слои и сущности', () async {
    final src = _dxf('');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final annotations = [
      Annotation(
        id: 'a1',
        drawingId: 'd1',
        number: 7,
        dxfX: 2,
        dxfY: 2,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    final measurements = <Measurement>[
      DistanceMeasurement(
        id: 'm1',
        drawingId: 'd1',
        createdAt: DateTime(2026, 1, 1),
        point1: const Offset(0, 0),
        point2: const Offset(4, 0),
      ),
    ];
    final out = _export(
      src,
      annotations: annotations,
      measurements: measurements,
      options: const DxfExportOptions(),
    );
    final parsed = await _parseOut(out);
    expect(
        parsed.layers.map((l) => l.name), containsAll(['Точки', 'Измерения']));
    expect(parsed.entities.any((e) => e.layer == 'Точки'), isTrue);
    expect(parsed.entities.any((e) => e.layer == 'Измерения'), isTrue);

    final noLayers =
        _export(src, annotations: annotations, measurements: measurements);
    final parsedNo = await _parseOut(noLayers);
    expect(parsedNo.layers.map((l) => l.name), isNot(contains('Точки')));
  });

  test('visibleLayersOnly пропускает скрытые слои', () async {
    final src = _dxf('');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final objects = [
      _o(DrawnType.point, const [Offset(1, 1)], layer: 'Слой 1'),
      _o(DrawnType.point, const [Offset(2, 2)], layer: 'Слой 2'),
    ];
    final out = _export(
      src,
      objects: objects,
      options: const DxfExportOptions(
        includePoints: false,
        includeMeasurements: false,
        visibleLayersOnly: true,
        hiddenDrawnLayers: {'Слой 2'},
      ),
    );
    final parsed = await _parseOut(out);
    final points = parsed.entities.whereType<DxfPoint>().toList();
    expect(points.length, 1);
    expect(points.first.x, closeTo(1, 1e-6));
    expect(parsed.layers.map((l) => l.name), contains('Слой 1'));
    expect(parsed.layers.map((l) => l.name), isNot(contains('Слой 2')));
  });

  test('кодировка: старый формат экранирует не-ASCII', () async {
    final modern = _dxf('', version: 'AC1032');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(modern)));
    final modernOut = utf8.decode(_export(modern, objects: [
      _o(DrawnType.text, const [Offset(1, 1)], text: 'Привет'),
    ]));
    expect(modernOut, contains(r'\U+041F'));
    expect(modernOut, isNot(contains('Привет')));

    final old = _dxf('', version: 'AC1015');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(old)));
    final oldOut = utf8.decode(_export(old, objects: [
      _o(DrawnType.text, const [Offset(1, 1)], text: 'Привет'),
    ]));
    expect(oldOut, contains(r'\U+041F'));
    expect(oldOut, isNot(contains('Привет')));
  });

  test('стиль без отступа кодов (0 вместо «  0»)', () async {
    final src = _dxf('', padCodes: false);
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _export(src, objects: [
      _o(DrawnType.point, const [Offset(1, 1)]),
    ]);
    final outStr = utf8.decode(out);
    expect(outStr, contains('POINT'));
    final parsed = await _parseOut(out);
    expect(parsed.entities.whereType<DxfPoint>().length, 1);
    expect(parsed.layers.map((l) => l.name), contains('Слой 1'));
  });

  test('CRLF и отступы кодов сохраняются', () async {
    final src = _dxf('', crlf: true);
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _export(src, objects: [
      _o(DrawnType.point, const [Offset(1, 1)]),
    ]);
    final outStr = utf8.decode(out);
    expect(outStr, contains('\r\n'));
    final parsed = await _parseOut(out);
    expect(parsed.entities.whereType<DxfPoint>().length, 1);
  });

  test('ZIP: DXF + фото + CSV + README', () async {
    final src = _dxf('');
    _lastDoc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final dxf = _export(src, objects: [
      _o(DrawnType.point, const [Offset(1, 1)])
    ]);
    final dir = Directory.systemTemp.createTempSync('dxf_export_test');
    final photoFile = File('${dir.path}/photo.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9]);
    final annotations = [
      Annotation(
        id: 'a1',
        drawingId: 'd1',
        number: 5,
        dxfX: 1,
        dxfY: 2,
        description: 'Опора; дерево',
        photos: [
          Photo(
            id: 'p1',
            annotationId: 'a1',
            localFilePath: photoFile.path,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    final zipBytes = await _service.buildZipFromParts(
      dxfBytes: dxf,
      annotations: annotations,
      drawingName: 'Тестовый чертёж',
      options: const DxfExportOptions(
        mode: DxfExportMode.withPhotos,
        photoQuality: ExportPhotoQuality.full,
      ),
    );
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('Тестовый_чертёж.dxf'));
    expect(names.any((n) => n.startsWith('photos/5_p1')), isTrue);
    expect(names, contains('points.csv'));
    expect(names, contains('README.txt'));
    final csvFile = archive.files.firstWhere((f) => f.name == 'points.csv');
    final csv = utf8.decode(csvFile.content as List<int>);
    expect(csv, contains('Номер;X;Y;Z'));
    expect(csv, contains('Опора; дерево'));
    expect(csv, contains('5_p1'));
    // DXF внутри архива парсится.
    final dxfFile = archive.files.firstWhere((f) => f.name.endsWith('.dxf'));
    final parsed =
        await _parseOut(Uint8List.fromList(dxfFile.content as List<int>));
    expect(parsed.layers.map((l) => l.name), contains('Слой 1'));
    dir.deleteSync(recursive: true);
  });

  test('современный формат: handle, владелец, subclass, HANDSEED', () async {
    final src = _dxfModern();
    final doc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _service.buildFromParts(
      originalBytes: Uint8List.fromList(utf8.encode(src)),
      document: doc,
      drawnObjects: [
        _o(DrawnType.rectangle,
            rectangleCorners(const Offset(1, 1), const Offset(5, 3))),
        _o(DrawnType.text, const [Offset(2, 2)], text: 'ПРИВЕТ', height: 1),
      ],
      annotations: const [],
      measurements: const [],
      options: const DxfExportOptions(
        includePoints: false,
        includeMeasurements: false,
      ),
      units: 'm',
      drawingName: 'modern',
    );
    final outStr = utf8.decode(out);
    // Подклассы обязательны для современного AutoCAD.
    expect(outStr, contains('AcDbEntity'));
    expect(outStr, contains('AcDbPolyline'));
    expect(outStr, contains('AcDbLayerTableRecord'));
    // Владелец — *Model_Space (handle 1F).
    expect(outStr, contains('330\n1F\n'));
    // Стиль печати (390) скопирован у существующего слоя — без него
    // AutoCAD не может импортировать LAYER-таблицу.
    expect(outStr, contains('390\nF\n'));
    expect(outStr, contains('347\nEE\n'));
    // Новые handle начинаются после $HANDSEED (200): 201 слой, 202 полилиния.
    expect(outStr, contains('  5\n201\n'));
    expect(outStr, contains('  5\n202\n'));
    // У TEXT второй AcDbText перед кодом 73 (иначе AutoCAD: «Неожиданный код 73»).
    expect(outStr, contains('100\nAcDbText\n 73\n2\n'));
    // $HANDSEED обновлён (rectangle 201, text 202, layer 203 → seed 204).
    expect(outStr, contains('\$HANDSEED\n  5\n204\n'));
    // $EXTMIN/$EXTMAX пересчитаны (были «пустые» 1e+20): значения с точкой,
    // как у AutoCAD (0.0, а не 0).
    expect(outStr, contains('\$EXTMIN\n 10\n0.0\n 20\n0.0\n 30\n0.0\n'));
    expect(outStr, contains('\$EXTMAX\n 10\n10.0\n 20\n3.0\n 30\n0.0\n'));
    // Исходная геометрия на месте.
    expect(outStr, contains('AcDbLine'));
    // Приложение перечитывает результат.
    final parsed = await DxfParser().parseBytes(out);
    expect(parsed.layers.map((l) => l.name), contains('Слой 1'));
    expect(parsed.entities.whereType<DxfLwPolyline>().length, 1);
  });

  test('корректные границы не переписываются (заголовок байт-в-байт)',
      () async {
    const bad = '  9\n\$EXTMIN\n 10\n1e+20\n 20\n1e+20\n 30\n1e+20\n'
        '  9\n\$EXTMAX\n 10\n-1e+20\n 20\n-1e+20\n 30\n-1e+20\n';
    const good = '  9\n\$EXTMIN\n 10\n12.345678\n 20\n0.0\n 30\n0.0\n'
        '  9\n\$EXTMAX\n 10\n100.98765\n 20\n50.5\n 30\n0.0\n';
    final src = _dxfModern().replaceFirst(bad, good);
    expect(src, isNot(equals(_dxfModern())));
    final doc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(src)));
    final out = _service.buildFromParts(
      originalBytes: Uint8List.fromList(utf8.encode(src)),
      document: doc,
      drawnObjects: [
        _o(DrawnType.rectangle,
            rectangleCorners(const Offset(1, 1), const Offset(5, 3))),
      ],
      annotations: const [],
      measurements: const [],
      options: const DxfExportOptions(
        includePoints: false,
        includeMeasurements: false,
      ),
      units: 'm',
      drawingName: 'valid',
    );
    final outStr = utf8.decode(out);
    // ignore: avoid_print
    // Валидные границы остались как были (не округлены до 4 знаков).
    expect(outStr, contains('\$EXTMIN\n 10\n12.345678\n'));
    expect(outStr, contains('\$EXTMAX\n 10\n100.98765\n'));
    expect(outStr, isNot(contains('12.3457')));
  });

  test('реальный snap_test.dxf: оригинал сохранён, новое добавлено', () async {
    final file = File('build/test_data/snap_test.dxf');
    if (!file.existsSync()) return;
    final original = file.readAsBytesSync();
    final doc = await DxfParser().parseBytes(original);
    final annotations = [
      Annotation(
        id: 'a1',
        drawingId: 'd1',
        number: 1,
        dxfX: 150,
        dxfY: 120,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    final measurements = <Measurement>[
      DistanceMeasurement(
        id: 'm1',
        drawingId: 'd1',
        createdAt: DateTime(2026, 1, 1),
        point1: const Offset(100, 100),
        point2: const Offset(300, 100),
      ),
    ];
    final objects = [
      _o(DrawnType.rectangle,
          rectangleCorners(const Offset(400, 150), const Offset(500, 200))),
      _o(DrawnType.text, const [Offset(420, 170)], text: 'Тест', height: 20),
    ];
    final out = _service.buildFromParts(
      originalBytes: original,
      document: doc,
      drawnObjects: objects,
      annotations: annotations,
      measurements: measurements,
      options: const DxfExportOptions(),
      units: 'm',
      drawingName: 'snap_test',
    );
    final parsed = await DxfParser().parseBytes(out);
    // Оригинальные сущности + 6 новых (прямоугольник+текст, точка, измерение).
    expect(parsed.entities.length, doc.entities.length + 6);
    expect(parsed.layers.map((l) => l.name),
        containsAll(['Слой 1', 'Точки', 'Измерения']));
    expect(parsed.layers.length, doc.layers.length + 3);
    // Исходное содержимое (заголовок, блоки) не потеряно.
    final outStr = utf8.decode(out);
    expect(outStr, contains('AC1032'));
    expect(outStr, contains('BLOCK'));
  });

  test('пустой исходник не бросает исключение', () async {
    final empty = Uint8List(0);
    _lastDoc = DxfDocument(
      layers: const [],
      entities: const [],
      minX: 0,
      minY: 0,
      maxX: 1,
      maxY: 1,
    );
    final out = _service.buildFromParts(
      originalBytes: empty,
      document: _lastDoc!,
      drawnObjects: [
        _o(DrawnType.point, const [Offset(1, 1)])
      ],
      annotations: const [],
      measurements: const [],
      options: const DxfExportOptions(),
      units: 'm',
      drawingName: 'empty',
    );
    expect(out.length, greaterThan(0));
  });
}
