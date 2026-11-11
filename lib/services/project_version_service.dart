import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/history_event.dart';
import '../models/project_version.dart';
import '../utils/format_utils.dart';
import 'database.dart';
import 'project_bundle.dart';

/// Версии проекта: снимки `.abris` в `<documents>/versions/<drawingId>/`.
class ProjectVersionService {
  static final ProjectVersionService instance = ProjectVersionService._();
  ProjectVersionService._();

  /// Сколько последних версий хранить на проект.
  static const int maxVersions = 20;

  final _db = DatabaseService.instance;
  final _bundle = ProjectBundle();

  /// Создаёт версию из текущего состояния проекта (фото сжимаются).
  Future<ProjectVersion> createVersion(
    String drawingId, {
    String? label,
    ExportPhotoQuality quality = ExportPhotoQuality.compact,
  }) async {
    final bytes = await _bundle.exportToBytes(drawingId, photoQuality: quality);
    final defaultLabel = 'Версия от ${formatDateTimeShort(DateTime.now())}';
    return _saveVersion(drawingId, bytes, label: label ?? defaultLabel);
  }

  /// Сохраняет версию из уже экспортированного файла `.abris` (без перепаковки).
  Future<ProjectVersion> addVersionFromFile(
    String drawingId,
    String sourcePath, {
    String? label,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final defaultLabel = 'Экспорт от ${formatDateTimeShort(DateTime.now())}';
    return _saveVersion(drawingId, bytes, label: label ?? defaultLabel);
  }

  Future<List<ProjectVersion>> list(String drawingId) =>
      _db.getProjectVersions(drawingId);

  Future<void> delete(ProjectVersion version) async {
    final file = File(version.filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    await _db.deleteProjectVersionRow(version.id);
  }

  /// Восстанавливает проект из версии. Перед этим создаёт страховочную версию.
  Future<void> restore(ProjectVersion version) async {
    await createVersion(version.drawingId, label: 'Перед восстановлением');
    await _db.clearProjectContent(version.drawingId);
    await _bundle.importFromZip(version.filePath, logHistory: false);
    await _db.logEvent(
      drawingId: version.drawingId,
      type: HistoryEventType.versionRestored,
      summary: 'Восстановлена версия «${version.label}»',
    );
  }

  Future<ProjectVersion> _saveVersion(
    String drawingId,
    List<int> bytes, {
    required String label,
  }) async {
    final annotations = await _db.getAnnotations(drawingId: drawingId);
    final measurements = await _db.getMeasurementsForDrawing(drawingId);
    final photos = annotations.fold<int>(0, (sum, a) => sum + a.photos.length);
    final audio =
        annotations.fold<int>(0, (sum, a) => sum + a.audioNotes.length);
    final dir = await _versionsDir(drawingId);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final file = File(
      p.join(dir.path, '${_stamp(now)}_$id.${ProjectBundle.extension}'),
    );
    await file.writeAsBytes(bytes);
    final version = ProjectVersion(
      id: id,
      drawingId: drawingId,
      label: label,
      filePath: file.path,
      sizeBytes: bytes.length,
      annotationsCount: annotations.length,
      measurementsCount: measurements.length,
      photosCount: photos,
      audioCount: audio,
      createdAt: now,
    );
    await _db.insertProjectVersion(version);
    await _db.logEvent(
      drawingId: drawingId,
      type: HistoryEventType.versionCreated,
      summary: 'Создана версия «$label» '
          '(${annotations.length} точек, ${formatBytes(bytes.length)})',
    );
    await _prune(drawingId);
    return version;
  }

  Future<void> _prune(String drawingId) async {
    final versions = await _db.getProjectVersions(drawingId);
    if (versions.length <= maxVersions) return;
    for (final old in versions.skip(maxVersions)) {
      await delete(old);
    }
  }

  Future<Directory> _versionsDir(String drawingId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'versions', _safe(drawingId)));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  String _stamp(DateTime dt) => '${dt.year}${_two(dt.month)}${_two(dt.day)}_'
      '${_two(dt.hour)}${_two(dt.minute)}${_two(dt.second)}';

  String _two(int value) => value.toString().padLeft(2, '0');
}
