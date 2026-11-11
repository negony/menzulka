import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/annotation.dart';
import '../models/audio_note.dart';
import '../models/drawn_object.dart';
import '../models/history_event.dart';
import '../models/measurement.dart';
import '../models/photo.dart';
import '../utils/format_utils.dart';
import '../utils/photo_compressor.dart';
import 'database.dart';

class ImportResult {
  final String drawingId;
  final String drawingName;
  final String dxfPath;
  ImportResult({
    required this.drawingId,
    required this.drawingName,
    required this.dxfPath,
  });
}

/// Качество фотографий при экспорте пакета.
enum ExportPhotoQuality {
  /// Оригиналы без изменений.
  full,

  /// Уменьшить до 1600 px и перекодировать в JPEG (по умолчанию).
  compact,

  /// Не включать фотографии (только чертёж и точки).
  none,
}

/// Портативный пакет проекта `.abris` (ZIP):
///   manifest.json + drawing.dxf + photos/<photoId>.<ext> + audio/<noteId>.<ext>
/// Позволяет перенести чертёж, точки (с описаниями), фото и голосовые заметки
/// между телефоном и ПК.
class ProjectBundle {
  final DatabaseService _db;
  ProjectBundle({DatabaseService? db}) : _db = db ?? DatabaseService.instance;

  static const String format = 'menzulka.project';
  static const int version = 3;
  static const String extension = 'abris';

  // ---------- ЭКСПОРТ ----------

  /// Собирает `.abris` в память (без записи на диск).
  Future<Uint8List> exportToBytes(
    String drawingId, {
    ExportPhotoQuality photoQuality = ExportPhotoQuality.compact,
    void Function(int done, int total)? onProgress,
  }) async {
    final drawing = await _db.getDrawingById(drawingId);
    if (drawing == null) throw StateError('Чертёж не найден');
    final annotations = await _db.getAnnotations(drawingId: drawingId);
    final measurements = await _db.getMeasurementsForDrawing(drawingId);
    final objects = await _db.getDrawnObjects(drawingId);

    final totalPhotos = photoQuality == ExportPhotoQuality.none
        ? 0
        : annotations.fold<int>(0, (sum, a) => sum + a.photos.length);
    var donePhotos = 0;

    final dxfFile = File(drawing.localFilePath);
    if (!await dxfFile.exists()) {
      throw StateError('Файл чертежа не найден: ${drawing.localFilePath}');
    }
    final dxfBytes = await dxfFile.readAsBytes();

    final archive = Archive();
    final manifestAnnotations = <Map<String, dynamic>>[];
    final photos = <String, List<int>>{};
    final audio = <String, List<int>>{};
    final usedNames = <String>{};

    for (final ann in annotations) {
      final photoList = <Map<String, dynamic>>[];
      if (photoQuality != ExportPhotoQuality.none) {
        for (final photo in ann.photos) {
          donePhotos++;
          final file = File(photo.localFilePath);
          if (await file.exists()) {
            var bytes = await file.readAsBytes();
            var ext = p.extension(photo.localFilePath);
            if (photoQuality == ExportPhotoQuality.compact) {
              bytes = await compressPhotoAsync(bytes);
              if (isJpegBytes(bytes)) ext = '.jpg';
            }
            final safeId = _sanitizeId(photo.id);
            var name = 'photos/$safeId$ext';
            var counter = 1;
            while (usedNames.contains(name)) {
              name = 'photos/${safeId}_$counter$ext';
              counter++;
            }
            usedNames.add(name);
            photos[name] = bytes;
            photoList.add({
              'id': photo.id,
              'file': name,
              'createdAt': photo.createdAt.toIso8601String(),
            });
          }
          onProgress?.call(donePhotos, totalPhotos);
        }
      }
      manifestAnnotations.add({
        'id': ann.id,
        'number': ann.number,
        'dxfX': ann.dxfX,
        'dxfY': ann.dxfY,
        'geoX': ann.geoX,
        'geoY': ann.geoY,
        'geoZ': ann.geoZ,
        'code': ann.code,
        'description': ann.description,
        'createdAt': ann.createdAt.toIso8601String(),
        'updatedAt': ann.updatedAt?.toIso8601String(),
        'photos': photoList,
        'audio': await _buildAudioJson(ann, audio, usedNames),
      });
    }

    final manifest = <String, dynamic>{
      'format': format,
      'version': version,
      'createdAt': DateTime.now().toIso8601String(),
      'drawing': {
        'id': drawing.id,
        'name': drawing.name,
        'units': drawing.units,
        'contentHash': drawing.contentHash,
      },
      'annotations': manifestAnnotations,
      'measurements': measurements.map(_measurementToJson).toList(),
      'objects': [for (final o in objects) o.toJson()],
    };

    final manifestBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
    archive.addFile(ArchiveFile('drawing.dxf', dxfBytes.length, dxfBytes));
    photos.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    audio.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw StateError('Не удалось сформировать архив');
    return Uint8List.fromList(zipData);
  }

  /// Экспортирует проект в файл `.abris` в `<documents>/exports/`.
  Future<String> exportToZip(
    String drawingId, {
    ExportPhotoQuality photoQuality = ExportPhotoQuality.compact,
    void Function(int done, int total)? onProgress,
  }) async {
    final zipData = await exportToBytes(
      drawingId,
      photoQuality: photoQuality,
      onProgress: onProgress,
    );
    final drawing = await _db.getDrawingById(drawingId);
    if (drawing == null) throw StateError('Чертёж не найден');
    final dir = await _subDir('exports');
    final base = _sanitizeFileName(drawing.name);
    var target = p.join(dir.path, '$base.$extension');
    var counter = 1;
    while (await File(target).exists()) {
      target = p.join(dir.path, '${base}_$counter.$extension');
      counter++;
    }
    await File(target).writeAsBytes(zipData);
    await _db.logEvent(
      drawingId: drawingId,
      type: HistoryEventType.projectExported,
      summary: 'Проект экспортирован (.abris, '
          '${_qualityLabel(photoQuality)}, ${formatBytes(zipData.length)})',
    );
    return target;
  }

  String _qualityLabel(ExportPhotoQuality quality) {
    switch (quality) {
      case ExportPhotoQuality.compact:
        return 'компактно';
      case ExportPhotoQuality.full:
        return 'полное качество';
      case ExportPhotoQuality.none:
        return 'без фото';
    }
  }

  // ---------- ИМПОРТ ----------

  Future<ImportResult> importFromZip(String zipPath,
          {bool logHistory = true}) async =>
      importFromBytes(await File(zipPath).readAsBytes(),
          logHistory: logHistory);

  /// Импорт из байтов — работает и с content:// URI (Android).
  Future<ImportResult> importFromBytes(List<int> bytes,
      {bool logHistory = true}) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? manifestFile;
    ArchiveFile? dxfFile;
    final files = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      files[name] = f;
      if (name == 'manifest.json') manifestFile = f;
      if (name == 'drawing.dxf') dxfFile = f;
    }
    if (manifestFile == null || dxfFile == null) {
      throw const FormatException('В пакете нет manifest.json или drawing.dxf');
    }

    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
        as Map<String, dynamic>;
    if (manifest['format'] != format) {
      throw const FormatException('Неверный формат пакета');
    }
    final fileVersion = (manifest['version'] as num?)?.toInt() ?? 0;
    if (fileVersion > version) {
      throw const FormatException(
          'Пакет создан более новой версией приложения');
    }

    final drawingJson =
        manifest['drawing'] as Map<String, dynamic>? ?? const {};
    final drawingId = (drawingJson['id'] as String?) ?? const Uuid().v4();
    final drawingName =
        (drawingJson['name'] as String?) ?? 'Импортированный чертёж';
    final units = (drawingJson['units'] as String?) ?? 'm';

    final dxfBytes = dxfFile.content as List<int>;
    final hash = sha256.convert(dxfBytes).toString();

    final drawingsDir = await _subDir('drawings');
    final dxfPath = p.join(drawingsDir.path, '$drawingId.dxf');
    await File(dxfPath).writeAsBytes(dxfBytes);

    await _db.upsertDrawing(
      id: drawingId,
      name: drawingName,
      localFilePath: dxfPath,
      units: units,
      contentHash: hash,
    );

    final photosDir = await _subDir('photos');
    final audioDir = await _subDir('audio');

    for (final a in (manifest['annotations'] as List? ?? const [])) {
      final annJson = a as Map<String, dynamic>;
      final annId = (annJson['id'] as String?) ?? const Uuid().v4();
      final photos = <Photo>[];
      for (final ph in (annJson['photos'] as List? ?? const [])) {
        final pj = ph as Map<String, dynamic>;
        final rel = (pj['file'] as String?) ?? '';
        final archiveFile = files[rel];
        if (archiveFile == null) continue;
        final photoId = (pj['id'] as String?) ?? const Uuid().v4();
        final ext = p.extension(rel);
        final localPath = p.join(photosDir.path, '${_sanitizeId(photoId)}$ext');
        await File(localPath).writeAsBytes(archiveFile.content as List<int>);
        photos.add(Photo(
          id: photoId,
          annotationId: annId,
          localFilePath: localPath,
          createdAt: _parseDate(pj['createdAt']) ?? DateTime.now(),
        ));
      }
      final audioNotes = <AudioNote>[];
      for (final an in (annJson['audio'] as List? ?? const [])) {
        final aj = an as Map<String, dynamic>;
        final rel = (aj['file'] as String?) ?? '';
        final archiveFile = files[rel];
        if (archiveFile == null) continue;
        final noteId = (aj['id'] as String?) ?? const Uuid().v4();
        final ext = p.extension(rel);
        final localPath = p.join(audioDir.path, '${_sanitizeId(noteId)}$ext');
        await File(localPath).writeAsBytes(archiveFile.content as List<int>);
        final note = AudioNote.fromJson(
          aj,
          localFilePath: localPath,
          annotationId: annId,
        );
        if (note != null) audioNotes.add(note);
      }
      await _db.upsertAnnotation(Annotation(
        id: annId,
        drawingId: drawingId,
        number: (annJson['number'] as num?)?.toInt() ?? 0,
        dxfX: (annJson['dxfX'] as num?)?.toDouble() ?? 0,
        dxfY: (annJson['dxfY'] as num?)?.toDouble() ?? 0,
        geoX: (annJson['geoX'] as num?)?.toDouble(),
        geoY: (annJson['geoY'] as num?)?.toDouble(),
        geoZ: (annJson['geoZ'] as num?)?.toDouble(),
        code: annJson['code'] as String?,
        description: annJson['description'] as String?,
        photos: photos,
        audioNotes: audioNotes,
        createdAt: _parseDate(annJson['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDate(annJson['updatedAt']),
      ));
    }

    for (final m in (manifest['measurements'] as List? ?? const [])) {
      final measurement =
          _measurementFromJson(m as Map<String, dynamic>, drawingId);
      if (measurement != null) {
        await _db.insertMeasurement(measurement, logHistory: false);
      }
    }

    // Нарисованные объекты (появились в версии пакета 3).
    for (final o in (manifest['objects'] as List? ?? const [])) {
      final object = DrawnObject.fromJson(o as Map<String, dynamic>, drawingId);
      if (object != null) {
        await _db.insertDrawnObject(object);
      }
    }

    if (logHistory) {
      final annotationCount =
          (manifest['annotations'] as List? ?? const []).length;
      await _db.logEvent(
        drawingId: drawingId,
        type: HistoryEventType.projectImported,
        summary: 'Проект импортирован: $annotationCount точек',
      );
    }

    return ImportResult(
      drawingId: drawingId,
      drawingName: drawingName,
      dxfPath: dxfPath,
    );
  }

  // ---------- helpers ----------

  Future<Directory> _subDir(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final sub = Directory(p.join(dir.path, name));
    if (!await sub.exists()) await sub.create(recursive: true);
    return sub;
  }

  String _sanitizeId(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  String _sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'project' : cleaned;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  /// Кладёт аудиофайлы аннотации в архив и возвращает их JSON-описание.
  Future<List<Map<String, dynamic>>> _buildAudioJson(
    Annotation ann,
    Map<String, List<int>> audio,
    Set<String> usedNames,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final note in ann.audioNotes) {
      final file = File(note.localFilePath);
      if (!await file.exists()) continue;
      final ext = p.extension(note.localFilePath);
      final safeId = _sanitizeId(note.id);
      var name = 'audio/$safeId$ext';
      var counter = 1;
      while (usedNames.contains(name)) {
        name = 'audio/${safeId}_$counter$ext';
        counter++;
      }
      usedNames.add(name);
      audio[name] = await file.readAsBytes();
      result.add({...note.toJson(), 'file': name});
    }
    return result;
  }

  Map<String, dynamic> _measurementToJson(Measurement m) {
    final points = <double>[];
    final type = m is DistanceMeasurement
        ? 'distance'
        : m is PolygonMeasurement
            ? (m.closed ? 'polygon' : 'polyline')
            : 'other';
    if (m is DistanceMeasurement) {
      points.addAll([m.point1.dx, m.point1.dy, m.point2.dx, m.point2.dy]);
    } else if (m is PolygonMeasurement) {
      for (final o in m.points) {
        points.addAll([o.dx, o.dy]);
      }
    }
    return {
      'id': m.id,
      'type': type,
      'points': points,
      'createdAt': m.createdAt.toIso8601String(),
    };
  }

  Measurement? _measurementFromJson(Map<String, dynamic> j, String drawingId) {
    final id = (j['id'] as String?) ?? const Uuid().v4();
    final type = j['type'] as String? ?? 'distance';
    final raw = (j['points'] as List? ?? const [])
        .map((e) => (e as num).toDouble())
        .toList();
    final createdAt = _parseDate(j['createdAt']) ?? DateTime.now();
    if (type == 'distance' && raw.length >= 4) {
      return DistanceMeasurement(
        id: id,
        drawingId: drawingId,
        createdAt: createdAt,
        point1: Offset(raw[0], raw[1]),
        point2: Offset(raw[2], raw[3]),
      );
    }
    if (raw.length >= 4) {
      final points = <Offset>[];
      for (var i = 0; i + 1 < raw.length; i += 2) {
        points.add(Offset(raw[i], raw[i + 1]));
      }
      return PolygonMeasurement(
        id: id,
        drawingId: drawingId,
        createdAt: createdAt,
        points: points,
        closed: type != 'polyline',
      );
    }
    return null;
  }
}
