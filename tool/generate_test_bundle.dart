// ignore_for_file: avoid_print
// Генератор тестового пакета .abris: точки + синтетические фотографии.
//
// Запуск:
//   dart run tool/generate_test_bundle.dart
//   dart run tool/generate_test_bundle.dart --points 6 --photos-per-point 3
//   dart run tool/generate_test_bundle.dart --dxf "D:\\path\\file.dxf"
//   dart run tool/generate_test_bundle.dart --append-to <drawingId>:<name>
//
// По умолчанию создаёт build/test_data/test_project_6x3.abris:
//   6 точек, в каждой по 3 синтетических фото 3000x2000 (JPEG).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _format = 'menzulka.project';
const _version = 1;

/// Смещения координат точек (единицы DXF).
const _offsets = <List<double>>[
  [0, 0],
  [30, 20],
  [-25, 35],
  [20, -30],
  [-30, -20],
  [0, 40],
  [40, 0],
  [-40, 10],
  [10, -40],
  [-10, 45],
];

void main(List<String> args) {
  final opts = _parseArgs(args);
  final outPath = opts['out'] ??
      p.join(Directory.current.path, 'build', 'test_data',
          'test_project_6x3.abris');
  final points = int.tryParse(opts['points'] ?? '6') ?? 6;
  final photosPerPoint = int.tryParse(opts['photos-per-point'] ?? '3') ?? 3;
  final width = int.tryParse(opts['width'] ?? '3000') ?? 3000;
  final height = int.tryParse(opts['height'] ?? '2000') ?? 2000;
  final quality = int.tryParse(opts['quality'] ?? '85') ?? 85;
  final appendTo = opts['append-to'];

  const uuid = Uuid();
  final now = DateTime.now().toIso8601String();

  // --- DXF: образец, если есть, иначе минимальный сгенерированный ---
  final sample = File(opts['dxf'] ?? _defaultDxfPath());
  final useSample = sample.existsSync();
  final Uint8List dxfBytes;
  final double baseX;
  final double baseY;
  if (useSample) {
    dxfBytes = sample.readAsBytesSync();
    baseX = 2550;
    baseY = -18450;
  } else {
    baseX = 100;
    baseY = 100;
    dxfBytes =
        Uint8List.fromList(utf8.encode(_generateDxf(baseX, baseY, points)));
  }

  // --- чертёж ---
  final appendParts = appendTo?.split(':');
  final drawingId = appendParts != null && appendParts.isNotEmpty
      ? appendParts.first
      : uuid.v4();
  final drawingName = appendParts != null && appendParts.length > 1
      ? appendParts.sublist(1).join(':')
      : 'TestProject_${points}x$photosPerPoint';

  // --- точки и фото ---
  final builtAnnotations = <Map<String, dynamic>>[];
  final photoEntries = <String, List<int>>{};
  final startNumber = appendTo != null ? 2 : 1;
  final count =
      appendTo != null ? (points - 1).clamp(0, _offsets.length) : points;

  for (var i = 0; i < count; i++) {
    final offset = _offsets[i % _offsets.length];
    final annotationId = uuid.v4();
    final photosJson = <Map<String, dynamic>>[];
    for (var j = 0; j < photosPerPoint; j++) {
      final photoId = uuid.v4();
      final photoBytes =
          _generatePhoto(width, height, quality, 'P${i + 1}-${j + 1}');
      final name = 'photos/$photoId.jpg';
      photoEntries[name] = photoBytes;
      photosJson.add({'id': photoId, 'file': name, 'createdAt': now});
    }
    builtAnnotations.add({
      'id': annotationId,
      'number': startNumber + i,
      'dxfX': baseX + offset[0],
      'dxfY': baseY + offset[1],
      'geoX': null,
      'geoY': null,
      'geoZ': null,
      'code': 'TEST',
      'description': 'Синтетическая точка ${startNumber + i}',
      'createdAt': now,
      'updatedAt': null,
      'photos': photosJson,
    });
  }

  // --- пакет ---
  final manifest = <String, dynamic>{
    'format': _format,
    'version': _version,
    'createdAt': now,
    'drawing': {
      'id': drawingId,
      'name': drawingName,
      'units': 'm',
      'contentHash': null,
    },
    'annotations': builtAnnotations,
    'measurements': <dynamic>[],
  };

  final manifestBytes =
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
  final archive = Archive();
  archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
  archive.addFile(ArchiveFile('drawing.dxf', dxfBytes.length, dxfBytes));
  photoEntries.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });

  final zip = ZipEncoder().encode(archive);
  if (zip == null) {
    stderr.writeln('Не удалось сформировать архив');
    exit(1);
  }
  final out = File(outPath);
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(zip);

  final photoTotal =
      photoEntries.values.fold<int>(0, (sum, b) => sum + b.length);
  print('Чертёж: $drawingName (id: $drawingId)');
  print('Точек: ${builtAnnotations.length}, фото: ${photoEntries.length}');
  print('Сумма фото: ${_mb(photoTotal)}, DXF: ${_mb(dxfBytes.length)}');
  print('Пакет: $outPath — ${_mb(zip.length)}');
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} МБ';

String _defaultDxfPath() =>
    r'D:\Documents\ХАЛТУРА\с рабочего стола\Jobs\M_TOPOS_POIMA.DXF';

String _generateDxf(double cx, double cy, int points) {
  final buffer = StringBuffer();
  void pair(String code, String value) {
    buffer.writeln(code);
    buffer.writeln(value);
  }

  final minX = cx - 80;
  final maxX = cx + 80;
  final minY = cy - 80;
  final maxY = cy + 80;

  pair('0', 'SECTION');
  pair('2', 'ENTITIES');
  final corners = <List<double>>[
    [minX, minY, maxX, minY],
    [maxX, minY, maxX, maxY],
    [maxX, maxY, minX, maxY],
    [minX, maxY, minX, minY],
  ];
  for (final c in corners) {
    pair('0', 'LINE');
    pair('8', '0');
    pair('10', c[0].toStringAsFixed(3));
    pair('20', c[1].toStringAsFixed(3));
    pair('11', c[2].toStringAsFixed(3));
    pair('21', c[3].toStringAsFixed(3));
  }
  for (var i = 0; i < points; i++) {
    final offset = _offsets[i % _offsets.length];
    pair('0', 'POINT');
    pair('8', '0');
    pair('10', (cx + offset[0]).toStringAsFixed(3));
    pair('20', (cy + offset[1]).toStringAsFixed(3));
  }
  pair('0', 'ENDSEC');
  pair('0', 'EOF');
  return buffer.toString();
}

Uint8List _generatePhoto(int width, int height, int quality, String label) {
  var image = img.Image(width: width, height: height);
  final base = label.hashCode.abs() % 160;
  img.fill(
    image,
    color: img.ColorRgb8(40 + base, 90, 160 - (base ~/ 2)),
  );
  image = img.noise(image, 6);
  // пара цветных прямоугольников — структура для реалистичности
  img.fillRect(
    image,
    x1: (width * 0.15).round(),
    y1: (height * 0.45).round(),
    x2: (width * 0.55).round(),
    y2: (height * 0.75).round(),
    color: img.ColorRgb8(230, 200, 60),
  );
  img.fillRect(
    image,
    x1: (width * 0.6).round(),
    y1: (height * 0.2).round(),
    x2: (width * 0.9).round(),
    y2: (height * 0.4).round(),
    color: img.ColorRgb8(60, 180, 90),
  );
  img.fillRect(
    image,
    x1: 40,
    y1: 40,
    x2: (width * 0.45).round(),
    y2: 220,
    color: img.ColorRgb8(20, 20, 20),
  );
  img.drawString(
    image,
    label,
    font: img.arial48,
    x: 70,
    y: 90,
    color: img.ColorRgb8(255, 255, 255),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      result[key] = args[i + 1];
      i++;
    } else {
      result[key] = 'true';
    }
  }
  return result;
}
