import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/annotation.dart';
import '../models/audio_note.dart';
import '../models/drawn_object.dart';
import '../models/history_event.dart';
import '../models/measurement.dart';
import '../models/photo.dart';
import '../models/project_version.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Projects,
  Drawings,
  AnnotationRows,
  PhotoRows,
  AudioNoteRows,
  MeasurementRows,
  DrawnObjectRows,
  HistoryEventRows,
  ProjectVersionRows,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(drawings, drawings.contentHash);
          }
          if (from < 3) {
            await m.createTable(audioNoteRows);
          }
          if (from < 4) {
            await m.createTable(historyEventRows);
            await m.createTable(projectVersionRows);
          }
          if (from < 5) {
            await m.createTable(drawnObjectRows);
          }
          if (from < 6) {
            await m.addColumn(drawnObjectRows, drawnObjectRows.rotation);
          }
          if (from < 7) {
            await m.addColumn(drawnObjectRows, drawnObjectRows.layer);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'menzulka.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Drawings extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get name => text()();
  TextColumn get localFilePath => text()();
  TextColumn get units => text().withDefault(const Constant('m'))();
  IntColumn get nextAnnotationNumber =>
      integer().withDefault(const Constant(1))();
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class AnnotationRows extends Table {
  TextColumn get id => text()();
  TextColumn get drawingId => text()();
  IntColumn get number => integer()();
  RealColumn get dxfX => real()();
  RealColumn get dxfY => real()();
  RealColumn get geoX => real().nullable()();
  RealColumn get geoY => real().nullable()();
  RealColumn get geoZ => real().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

// Переименовано из Photos в PhotoRows, чтобы избежать конфликта имен
class PhotoRows extends Table {
  TextColumn get id => text()();
  TextColumn get annotationId => text()();
  TextColumn get localFilePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isUploaded => boolean().withDefault(const Constant(false))();
  TextColumn get fileUrl => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class AudioNoteRows extends Table {
  TextColumn get id => text()();
  TextColumn get annotationId => text()();
  TextColumn get localFilePath => text()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class HistoryEventRows extends Table {
  TextColumn get id => text()();
  TextColumn get drawingId => text()();
  TextColumn get annotationId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get summary => text()();
  TextColumn get detailsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class ProjectVersionRows extends Table {
  TextColumn get id => text()();
  TextColumn get drawingId => text()();
  TextColumn get label => text()();
  TextColumn get filePath => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get annotationsCount => integer().withDefault(const Constant(0))();
  IntColumn get measurementsCount => integer().withDefault(const Constant(0))();
  IntColumn get photosCount => integer().withDefault(const Constant(0))();
  IntColumn get audioCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class MeasurementRows extends Table {
  TextColumn get id => text()();
  TextColumn get drawingId => text()();
  TextColumn get type => text()();
  TextColumn get pointsJson => text()();
  TextColumn get annotationIdsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

/// Нарисованные пользователем объекты (режим «Рисование»).
class DrawnObjectRows extends Table {
  TextColumn get id => text()();
  TextColumn get drawingId => text()();
  TextColumn get type => text()();
  TextColumn get pointsJson => text()();
  TextColumn get bulgesJson => text().nullable()();
  TextColumn get content => text().nullable()();
  RealColumn get height => real().nullable()();
  IntColumn get color =>
      integer().withDefault(const Constant(kDrawnDefaultColor))();
  RealColumn get strokePx =>
      real().withDefault(const Constant(kDrawnDefaultStrokePx))();
  RealColumn get rotation => real().withDefault(const Constant(0))();
  TextColumn get layer =>
      text().withDefault(const Constant(kDefaultDrawnLayer))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();
  late final AppDatabase _db = AppDatabase();
  Future<AppDatabase> get database async => _db;

  Stream<List<Annotation>> watchAnnotations({
    required String drawingId,
    String searchQuery = '',
    String filter = 'all',
    String sortBy = 'number',
  }) async* {
    yield await getAnnotations(
      drawingId: drawingId,
      searchQuery: searchQuery,
      filter: filter,
      sortBy: sortBy,
    );
  }

  Future<List<Annotation>> getAnnotations({
    required String drawingId,
    String searchQuery = '',
    String filter = 'all',
    String sortBy = 'number',
  }) async {
    var query = _db.select(_db.annotationRows)
      ..where((a) => a.drawingId.equals(drawingId))
      ..where((a) => a.deletedAt.isNull());
    if (searchQuery.isNotEmpty) {
      query.where((a) =>
          a.code.contains(searchQuery) | a.description.contains(searchQuery));
    }
    if (filter == 'with_code') {
      // Исправлено: используем выражения Drift вместо обычных операторов Dart
      query.where((a) => a.code.isNotNull() & a.code.equals('').not());
    }
    switch (sortBy) {
      case 'number':
        query.orderBy([(a) => OrderingTerm.asc(a.number)]);
        break;
      case 'date':
        query.orderBy([(a) => OrderingTerm.desc(a.createdAt)]);
        break;
      case 'code':
        query.orderBy([(a) => OrderingTerm.asc(a.code)]);
        break;
    }
    final rows = await query.get();
    final result = <Annotation>[];
    for (final row in rows) {
      final photos = await _getPhotosForAnnotation(row.id);
      final audio = await _getAudioForAnnotation(row.id);
      result.add(Annotation(
        id: row.id,
        drawingId: row.drawingId,
        number: row.number,
        dxfX: row.dxfX,
        dxfY: row.dxfY,
        geoX: row.geoX,
        geoY: row.geoY,
        geoZ: row.geoZ,
        code: row.code,
        description: row.description,
        photos: photos,
        audioNotes: audio,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      ));
    }
    return result;
  }

  Future<List<Photo>> _getPhotosForAnnotation(String annotationId) async {
    final rows = await (_db.select(_db.photoRows)
          ..where((p) => p.annotationId.equals(annotationId)))
        .get();
    return rows
        .map((r) => Photo(
              id: r.id,
              annotationId: r.annotationId,
              localFilePath: r.localFilePath,
              thumbnailPath: r.thumbnailPath,
              createdAt: r.createdAt,
              isUploaded: r.isUploaded,
              fileUrl: r.fileUrl,
            ))
        .toList();
  }

  Future<List<AudioNote>> _getAudioForAnnotation(String annotationId) async {
    final rows = await (_db.select(_db.audioNoteRows)
          ..where((a) => a.annotationId.equals(annotationId)))
        .get();
    return rows
        .map((r) => AudioNote(
              id: r.id,
              annotationId: r.annotationId,
              localFilePath: r.localFilePath,
              durationMs: r.durationMs,
              createdAt: r.createdAt,
            ))
        .toList();
  }

  /// Копирует фото во внутреннее хранилище приложения и возвращает постоянный
  /// путь. Файл из кэша image_picker нельзя хранить — он пропадёт.
  Future<String> savePhotoFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDirPath = p.join(dir.path, 'photos');
    final photosDir = Directory(photosDirPath);
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;
    final normalizedSource = p.normalize(source.absolute.path);
    final normalizedDir = p.normalize(photosDir.absolute.path);
    if (p.isWithin(normalizedDir, normalizedSource)) return sourcePath;
    var name = p.basename(sourcePath);
    var target = File(p.join(photosDirPath, name));
    var counter = 1;
    while (await target.exists()) {
      final ext = p.extension(name);
      final base = p.basenameWithoutExtension(name);
      target = File(p.join(photosDirPath, '${base}_$counter$ext'));
      counter++;
    }
    await source.copy(target.path);
    return target.path;
  }

  /// Копирует аудиозаметку во внутреннее хранилище (`<documents>/audio/`)
  /// и возвращает постоянный путь.
  Future<String> saveAudioFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDirPath = p.join(dir.path, 'audio');
    final audioDir = Directory(audioDirPath);
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;
    final normalizedSource = p.normalize(source.absolute.path);
    final normalizedDir = p.normalize(audioDir.absolute.path);
    if (p.isWithin(normalizedDir, normalizedSource)) return sourcePath;
    final name = p.basename(sourcePath);
    var target = File(p.join(audioDirPath, name));
    var counter = 1;
    while (await target.exists()) {
      final ext = p.extension(name);
      final base = p.basenameWithoutExtension(name);
      target = File(p.join(audioDirPath, '${base}_$counter$ext'));
      counter++;
    }
    await source.copy(target.path);
    return target.path;
  }

  Future<void> insertAnnotation(Annotation annotation) async {
    await _db.into(_db.annotationRows).insert(AnnotationRowsCompanion.insert(
          id: annotation.id,
          drawingId: annotation.drawingId,
          number: annotation.number,
          dxfX: annotation.dxfX,
          dxfY: annotation.dxfY,
          geoX: Value(annotation.geoX),
          geoY: Value(annotation.geoY),
          geoZ: Value(annotation.geoZ),
          code: Value(annotation.code),
          description: Value(annotation.description),
        ));
    for (final photo in annotation.photos) {
      // Привязываем фото к аннотации по её id и копируем файл в постоянное
      // хранилище (иначе фото пропадает после очистки кэша).
      final savedPath = await savePhotoFile(photo.localFilePath);
      await _db.into(_db.photoRows).insert(PhotoRowsCompanion.insert(
            id: photo.id,
            annotationId: annotation.id,
            localFilePath: savedPath,
            thumbnailPath: Value(photo.thumbnailPath),
          ));
    }
    for (final note in annotation.audioNotes) {
      final savedPath = await saveAudioFile(note.localFilePath);
      await _db.into(_db.audioNoteRows).insert(AudioNoteRowsCompanion.insert(
            id: note.id,
            annotationId: annotation.id,
            localFilePath: savedPath,
            durationMs: Value(note.durationMs),
          ));
    }
    final extra = <String>[
      if (annotation.photos.isNotEmpty) '${annotation.photos.length} фото',
      if (annotation.audioNotes.isNotEmpty)
        '${annotation.audioNotes.length} заметок',
    ];
    await logEvent(
      drawingId: annotation.drawingId,
      annotationId: annotation.id,
      type: HistoryEventType.annotationCreated,
      summary: 'Точка №${annotation.number} создана'
          '${extra.isEmpty ? '' : ' (${extra.join(', ')})'}',
    );
  }

  /// Полностью заменяет набор фото аннотации (для редактирования карточки).
  Future<void> replacePhotos(String annotationId, List<Photo> photos) async {
    final row = await _annotationRow(annotationId);
    final oldIds =
        (await _getPhotosForAnnotation(annotationId)).map((p) => p.id).toSet();
    await (_db.delete(_db.photoRows)
          ..where((t) => t.annotationId.equals(annotationId)))
        .go();
    for (final photo in photos) {
      final savedPath = await savePhotoFile(photo.localFilePath);
      await _db.into(_db.photoRows).insert(PhotoRowsCompanion.insert(
            id: photo.id,
            annotationId: annotationId,
            localFilePath: savedPath,
            thumbnailPath: Value(photo.thumbnailPath),
          ));
    }
    if (row != null) {
      final newIds = photos.map((p) => p.id).toSet();
      final added = newIds.difference(oldIds).length;
      final removed = oldIds.difference(newIds).length;
      if (added > 0) {
        await logEvent(
          drawingId: row.drawingId,
          annotationId: annotationId,
          type: HistoryEventType.photoAdded,
          summary: 'Точка №${row.number}: добавлено фото ($added)',
        );
      }
      if (removed > 0) {
        await logEvent(
          drawingId: row.drawingId,
          annotationId: annotationId,
          type: HistoryEventType.photoRemoved,
          summary: 'Точка №${row.number}: удалено фото ($removed)',
        );
      }
    }
  }

  /// Полностью заменяет набор голосовых заметок аннотации.
  Future<void> replaceAudioNotes(
      String annotationId, List<AudioNote> notes) async {
    final row = await _annotationRow(annotationId);
    final oldIds =
        (await _getAudioForAnnotation(annotationId)).map((n) => n.id).toSet();
    await (_db.delete(_db.audioNoteRows)
          ..where((t) => t.annotationId.equals(annotationId)))
        .go();
    for (final note in notes) {
      final savedPath = await saveAudioFile(note.localFilePath);
      await _db.into(_db.audioNoteRows).insert(AudioNoteRowsCompanion.insert(
            id: note.id,
            annotationId: annotationId,
            localFilePath: savedPath,
            durationMs: Value(note.durationMs),
          ));
    }
    if (row != null) {
      final newIds = notes.map((n) => n.id).toSet();
      final added = newIds.difference(oldIds).length;
      final removed = oldIds.difference(newIds).length;
      if (added > 0) {
        await logEvent(
          drawingId: row.drawingId,
          annotationId: annotationId,
          type: HistoryEventType.audioAdded,
          summary: 'Точка №${row.number}: добавлена голосовая заметка ($added)',
        );
      }
      if (removed > 0) {
        await logEvent(
          drawingId: row.drawingId,
          annotationId: annotationId,
          type: HistoryEventType.audioRemoved,
          summary: 'Точка №${row.number}: удалена голосовая заметка ($removed)',
        );
      }
    }
  }

  Future<void> updateAnnotation(Annotation annotation) async {
    final old = await _annotationRow(annotation.id);
    await (_db.update(_db.annotationRows)
          ..where((a) => a.id.equals(annotation.id)))
        .write(AnnotationRowsCompanion(
      number: Value(annotation.number),
      code: Value(annotation.code),
      description: Value(annotation.description),
      dxfX: Value(annotation.dxfX),
      dxfY: Value(annotation.dxfY),
      geoZ: Value(annotation.geoZ),
      updatedAt: Value(DateTime.now()),
    ));
    if (old != null) {
      final changed = <String>[
        if (old.number != annotation.number) 'номер',
        if (old.code != annotation.code) 'код',
        if (old.description != annotation.description) 'описание',
        if (old.dxfX != annotation.dxfX || old.dxfY != annotation.dxfY)
          'координаты X/Y',
        if (old.geoZ != annotation.geoZ) 'высота Z',
      ];
      if (changed.isNotEmpty) {
        await logEvent(
          drawingId: old.drawingId,
          annotationId: annotation.id,
          type: HistoryEventType.annotationUpdated,
          summary: 'Точка №${old.number} изменена: ${changed.join(', ')}',
          detailsJson: jsonEncode({'changed': changed}),
        );
      }
    }
  }

  Future<void> deleteAnnotation(String id) async {
    final row = await _annotationRow(id);
    await (_db.update(_db.annotationRows)..where((a) => a.id.equals(id)))
        .write(AnnotationRowsCompanion(deletedAt: Value(DateTime.now())));
    if (row != null) {
      await logEvent(
        drawingId: row.drawingId,
        annotationId: id,
        type: HistoryEventType.annotationDeleted,
        summary: 'Точка №${row.number} удалена',
      );
    }
  }

  Future<void> restoreAnnotation(String id) async {
    final row = await _annotationRow(id);
    await (_db.update(_db.annotationRows)..where((a) => a.id.equals(id)))
        .write(const AnnotationRowsCompanion(deletedAt: Value(null)));
    if (row != null) {
      await logEvent(
        drawingId: row.drawingId,
        annotationId: id,
        type: HistoryEventType.annotationRestored,
        summary: 'Точка №${row.number} восстановлена',
      );
    }
  }

  Future<void> deleteAnnotations(List<String> ids) async {
    final rows = await (_db.select(_db.annotationRows)
          ..where((a) => a.id.isIn(ids)))
        .get();
    await (_db.update(_db.annotationRows)..where((a) => a.id.isIn(ids)))
        .write(AnnotationRowsCompanion(deletedAt: Value(DateTime.now())));
    for (final row in rows) {
      await logEvent(
        drawingId: row.drawingId,
        annotationId: row.id,
        type: HistoryEventType.annotationDeleted,
        summary: 'Точка №${row.number} удалена',
      );
    }
  }

  Future<List<Annotation>> getAnnotationsByIds(List<String> ids) async {
    final rows = await (_db.select(_db.annotationRows)
          ..where((a) => a.id.isIn(ids)))
        .get();
    final result = <Annotation>[];
    for (final row in rows) {
      final photos = await _getPhotosForAnnotation(row.id);
      final audio = await _getAudioForAnnotation(row.id);
      result.add(Annotation(
        id: row.id,
        drawingId: row.drawingId,
        number: row.number,
        dxfX: row.dxfX,
        dxfY: row.dxfY,
        geoX: row.geoX,
        geoY: row.geoY,
        geoZ: row.geoZ,
        code: row.code,
        description: row.description,
        photos: photos,
        audioNotes: audio,
        createdAt: row.createdAt,
      ));
    }
    return result;
  }

  Future<Drawing?> getDrawingById(String id) async {
    final row = await (_db.select(_db.drawings)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return Drawing(
      id: row.id,
      projectId: row.projectId,
      name: row.name,
      localFilePath: row.localFilePath,
      units: row.units,
      nextAnnotationNumber: row.nextAnnotationNumber,
      contentHash: row.contentHash,
      createdAt: row.createdAt,
    );
  }

  Future<Drawing?> getDrawingByHash(String hash) async {
    final rows = await (_db.select(_db.drawings)
          ..where((d) => d.contentHash.equals(hash))
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Drawing>> getDrawings() async {
    return (_db.select(_db.drawings)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .get();
  }

  Future<void> upsertDrawing({
    required String id,
    required String name,
    required String localFilePath,
    String units = 'm',
    String? contentHash,
  }) async {
    await _db
        .into(_db.drawings)
        .insertOnConflictUpdate(DrawingsCompanion.insert(
          id: id,
          projectId: 'default',
          name: name,
          localFilePath: localFilePath,
          units: Value(units),
          contentHash: Value(contentHash),
        ));
  }

  /// Переносит старые аннотации/измерения с ключа-имени файла на новый id.
  Future<void> migrateLegacyDrawing(
      String oldDrawingId, String newDrawingId) async {
    if (oldDrawingId == newDrawingId) return;
    await (_db.update(_db.annotationRows)
          ..where((a) => a.drawingId.equals(oldDrawingId)))
        .write(AnnotationRowsCompanion(drawingId: Value(newDrawingId)));
    await (_db.update(_db.measurementRows)
          ..where((m) => m.drawingId.equals(oldDrawingId)))
        .write(MeasurementRowsCompanion(drawingId: Value(newDrawingId)));
  }

  /// Upsert аннотации (для импорта пакета) + замена набора фото.
  Future<void> upsertAnnotation(Annotation annotation) async {
    await _db.into(_db.annotationRows).insertOnConflictUpdate(
          AnnotationRowsCompanion.insert(
            id: annotation.id,
            drawingId: annotation.drawingId,
            number: annotation.number,
            dxfX: annotation.dxfX,
            dxfY: annotation.dxfY,
            geoX: Value(annotation.geoX),
            geoY: Value(annotation.geoY),
            geoZ: Value(annotation.geoZ),
            code: Value(annotation.code),
            description: Value(annotation.description),
            createdAt: Value(annotation.createdAt),
          ),
        );
    await (_db.delete(_db.photoRows)
          ..where((t) => t.annotationId.equals(annotation.id)))
        .go();
    for (final photo in annotation.photos) {
      await _db.into(_db.photoRows).insert(PhotoRowsCompanion.insert(
            id: photo.id,
            annotationId: annotation.id,
            localFilePath: photo.localFilePath,
            thumbnailPath: Value(photo.thumbnailPath),
            createdAt: Value(photo.createdAt),
          ));
    }
    await (_db.delete(_db.audioNoteRows)
          ..where((t) => t.annotationId.equals(annotation.id)))
        .go();
    for (final note in annotation.audioNotes) {
      await _db.into(_db.audioNoteRows).insert(AudioNoteRowsCompanion.insert(
            id: note.id,
            annotationId: annotation.id,
            localFilePath: note.localFilePath,
            durationMs: Value(note.durationMs),
            createdAt: Value(note.createdAt),
          ));
    }
  }

  Future<List<Measurement>> getMeasurementsForDrawing(String drawingId) async {
    final rows = await (_db.select(_db.measurementRows)
          ..where((m) => m.drawingId.equals(drawingId)))
        .get();
    return rows.map((row) => _measurementFromDb(row)).toList();
  }

  Stream<List<Measurement>> watchMeasurements({String filter = 'all'}) async* {
    yield await getMeasurements(filter: filter);
  }

  Future<List<Measurement>> getMeasurements({String filter = 'all'}) async {
    var query = _db.select(_db.measurementRows);
    if (filter == 'distance') {
      query.where((m) => m.type.equals('distance'));
    } else if (filter == 'polygon') {
      query.where((m) => m.type.equals('polygon') | m.type.equals('polyline'));
    }
    query.orderBy([(m) => OrderingTerm.desc(m.createdAt)]);
    final rows = await query.get();
    return rows.map((row) => _measurementFromDb(row)).toList();
  }

  Future<List<Measurement>> getAllMeasurements() async {
    final rows = await _db.select(_db.measurementRows).get();
    return rows.map((row) => _measurementFromDb(row)).toList();
  }

  Future<List<Measurement>> getMeasurementsByIds(List<String> ids) async {
    final rows = await (_db.select(_db.measurementRows)
          ..where((m) => m.id.isIn(ids)))
        .get();
    return rows.map((row) => _measurementFromDb(row)).toList();
  }

  Future<void> insertMeasurement(Measurement measurement,
      {bool logHistory = true}) async {
    List<double> pointsList;
    if (measurement is DistanceMeasurement) {
      pointsList = [
        measurement.point1.dx,
        measurement.point1.dy,
        measurement.point2.dx,
        measurement.point2.dy,
      ];
    } else if (measurement is PolygonMeasurement) {
      pointsList = [];
      for (final p in measurement.points) {
        pointsList.add(p.dx);
        pointsList.add(p.dy);
      }
    } else {
      return;
    }
    await _db
        .into(_db.measurementRows)
        .insertOnConflictUpdate(MeasurementRowsCompanion.insert(
          id: measurement.id,
          drawingId: measurement.drawingId,
          type: measurement is DistanceMeasurement
              ? 'distance'
              : ((measurement as PolygonMeasurement).closed
                  ? 'polygon'
                  : 'polyline'),
          pointsJson: jsonEncode(pointsList),
        ));
    final units = await _drawingUnits(measurement.drawingId);
    if (logHistory) {
      await logEvent(
        drawingId: measurement.drawingId,
        type: HistoryEventType.measurementCreated,
        summary: 'Измерение: '
            '${measurement.formatResult(units).replaceAll('\n', ', ')}',
      );
    }
  }

  Future<void> deleteMeasurement(String id) async {
    final rows = await (_db.select(_db.measurementRows)
          ..where((m) => m.id.equals(id)))
        .get();
    if (rows.isNotEmpty) {
      final m = _measurementFromDb(rows.first);
      final units = await _drawingUnits(m.drawingId);
      await logEvent(
        drawingId: m.drawingId,
        type: HistoryEventType.measurementDeleted,
        summary:
            'Измерение удалено: ${m.formatResult(units).replaceAll('\n', ', ')}',
      );
    }
    await (_db.delete(_db.measurementRows)..where((m) => m.id.equals(id))).go();
  }

  Future<void> deleteMeasurements(List<String> ids) async {
    final rows = await (_db.select(_db.measurementRows)
          ..where((m) => m.id.isIn(ids)))
        .get();
    for (final row in rows) {
      final m = _measurementFromDb(row);
      final units = await _drawingUnits(m.drawingId);
      await logEvent(
        drawingId: m.drawingId,
        type: HistoryEventType.measurementDeleted,
        summary:
            'Измерение удалено: ${m.formatResult(units).replaceAll('\n', ', ')}',
      );
    }
    await (_db.delete(_db.measurementRows)..where((m) => m.id.isIn(ids))).go();
  }

  // ---------- нарисованные объекты ----------

  Future<List<DrawnObject>> getDrawnObjects(String drawingId) async {
    final rows = await (_db.select(_db.drawnObjectRows)
          ..where((t) => t.drawingId.equals(drawingId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_drawnObjectFromRow).toList();
  }

  Future<void> insertDrawnObject(DrawnObject object) async {
    await _db.into(_db.drawnObjectRows).insertOnConflictUpdate(
          DrawnObjectRowsCompanion.insert(
            id: object.id,
            drawingId: object.drawingId,
            type: object.type.name,
            pointsJson: jsonEncode([
              for (final point in object.points) ...[point.dx, point.dy],
            ]),
            bulgesJson:
                Value(object.bulges.isEmpty ? null : jsonEncode(object.bulges)),
            content: Value(object.text),
            height: Value(object.height),
            color: Value(object.color),
            strokePx: Value(object.strokePx),
            rotation: Value(object.rotation),
            layer: Value(object.layer),
            createdAt: Value(object.createdAt),
          ),
        );
  }

  Future<void> deleteDrawnObject(String id) async {
    await (_db.delete(_db.drawnObjectRows)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteDrawnObjectsForDrawing(String drawingId) async {
    await (_db.delete(_db.drawnObjectRows)
          ..where((t) => t.drawingId.equals(drawingId)))
        .go();
  }

  Future<void> clearAllMeasurements() async {
    await _db.delete(_db.measurementRows).go();
  }

  // ---------- ЖУРНАЛ ПРОЕКТА ----------

  /// Добавляет событие в журнал проекта.
  Future<void> logEvent({
    required String drawingId,
    String? annotationId,
    required String type,
    required String summary,
    String? detailsJson,
  }) async {
    await _db
        .into(_db.historyEventRows)
        .insert(HistoryEventRowsCompanion.insert(
          id: const Uuid().v4(),
          drawingId: drawingId,
          annotationId: Value(annotationId),
          type: type,
          summary: summary,
          detailsJson: Value(detailsJson),
        ));
  }

  /// События журнала проекта (свежие сверху). [annotationId] — история точки.
  Future<List<HistoryEvent>> getHistory({
    required String drawingId,
    String? annotationId,
    List<String>? types,
    String search = '',
    int limit = 300,
  }) async {
    var query = _db.select(_db.historyEventRows)
      ..where((e) => e.drawingId.equals(drawingId));
    if (annotationId != null) {
      query.where((e) => e.annotationId.equals(annotationId));
    }
    if (types != null && types.isNotEmpty) {
      query.where((e) => e.type.isIn(types));
    }
    if (search.isNotEmpty) {
      query.where((e) => e.summary.contains(search));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.createdAt)]);
    query.limit(limit);
    final rows = await query.get();
    return rows.map(_historyEventFromRow).toList();
  }

  Future<List<HistoryEvent>> getHistoryForAnnotation(
    String annotationId, {
    int limit = 100,
  }) async {
    final rows = await (_db.select(_db.historyEventRows)
          ..where((e) => e.annotationId.equals(annotationId))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_historyEventFromRow).toList();
  }

  HistoryEvent _historyEventFromRow(HistoryEventRow row) => HistoryEvent(
        id: row.id,
        drawingId: row.drawingId,
        annotationId: row.annotationId,
        type: row.type,
        summary: row.summary,
        detailsJson: row.detailsJson,
        createdAt: row.createdAt,
      );

  // ---------- ВЕРСИИ ПРОЕКТА ----------

  Future<List<ProjectVersion>> getProjectVersions(String drawingId) async {
    final rows = await (_db.select(_db.projectVersionRows)
          ..where((v) => v.drawingId.equals(drawingId))
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .get();
    return rows.map(_projectVersionFromRow).toList();
  }

  Future<void> insertProjectVersion(ProjectVersion version) async {
    await _db.into(_db.projectVersionRows).insert(
          ProjectVersionRowsCompanion.insert(
            id: version.id,
            drawingId: version.drawingId,
            label: version.label,
            filePath: version.filePath,
            sizeBytes: Value(version.sizeBytes),
            annotationsCount: Value(version.annotationsCount),
            measurementsCount: Value(version.measurementsCount),
            photosCount: Value(version.photosCount),
            audioCount: Value(version.audioCount),
            createdAt: Value(version.createdAt),
          ),
        );
  }

  Future<void> deleteProjectVersionRow(String id) async {
    await (_db.delete(_db.projectVersionRows)..where((v) => v.id.equals(id)))
        .go();
  }

  ProjectVersion _projectVersionFromRow(ProjectVersionRow row) =>
      ProjectVersion(
        id: row.id,
        drawingId: row.drawingId,
        label: row.label,
        filePath: row.filePath,
        sizeBytes: row.sizeBytes,
        annotationsCount: row.annotationsCount,
        measurementsCount: row.measurementsCount,
        photosCount: row.photosCount,
        audioCount: row.audioCount,
        createdAt: row.createdAt,
      );

  /// Полностью удаляет содержимое проекта (точки, фото, заметки, измерения).
  /// Используется при восстановлении версии.
  Future<void> clearProjectContent(String drawingId) async {
    final annotationRows = await (_db.select(_db.annotationRows)
          ..where((a) => a.drawingId.equals(drawingId)))
        .get();
    for (final row in annotationRows) {
      await (_db.delete(_db.photoRows)
            ..where((p) => p.annotationId.equals(row.id)))
          .go();
      await (_db.delete(_db.audioNoteRows)
            ..where((p) => p.annotationId.equals(row.id)))
          .go();
    }
    await (_db.delete(_db.annotationRows)
          ..where((a) => a.drawingId.equals(drawingId)))
        .go();
    await (_db.delete(_db.measurementRows)
          ..where((m) => m.drawingId.equals(drawingId)))
        .go();
  }

  Future<AnnotationRow?> _annotationRow(String id) async {
    final rows = await (_db.select(_db.annotationRows)
          ..where((a) => a.id.equals(id)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> _drawingUnits(String drawingId) async {
    final drawing = await getDrawingById(drawingId);
    return drawing?.units ?? 'm';
  }

  Measurement _measurementFromDb(MeasurementRow row) {
    final pointsJson = jsonDecode(row.pointsJson) as List<dynamic>;
    final points = <ui.Offset>[];
    for (int i = 0; i < pointsJson.length; i += 2) {
      points.add(ui.Offset(
        (pointsJson[i] as num).toDouble(),
        (pointsJson[i + 1] as num).toDouble(),
      ));
    }
    if (row.type == 'distance' && points.length == 2) {
      return DistanceMeasurement(
        id: row.id,
        drawingId: row.drawingId,
        createdAt: row.createdAt,
        point1: points[0],
        point2: points[1],
      );
    } else {
      return PolygonMeasurement(
        id: row.id,
        drawingId: row.drawingId,
        createdAt: row.createdAt,
        points: points,
        closed: row.type != 'polyline',
      );
    }
  }

  DrawnObject _drawnObjectFromRow(DrawnObjectRow row) {
    final rawPoints =
        (jsonDecode(row.pointsJson) as List<dynamic>?) ?? const [];
    final points = <ui.Offset>[];
    for (var i = 0; i + 1 < rawPoints.length; i += 2) {
      points.add(ui.Offset(
        (rawPoints[i] as num).toDouble(),
        (rawPoints[i + 1] as num).toDouble(),
      ));
    }
    final rawBulges =
        row.bulgesJson == null ? null : jsonDecode(row.bulgesJson!);
    final bulges = <double>[
      for (final b in (rawBulges as List<dynamic>?) ?? const [])
        (b as num).toDouble(),
    ];
    var type = DrawnType.point;
    for (final t in DrawnType.values) {
      if (t.name == row.type) {
        type = t;
        break;
      }
    }
    return DrawnObject(
      id: row.id,
      drawingId: row.drawingId,
      type: type,
      points: points,
      bulges: bulges,
      text: row.content,
      height: row.height,
      color: row.color,
      strokePx: row.strokePx,
      rotation: row.rotation,
      layer: row.layer,
      createdAt: row.createdAt,
    );
  }
}
