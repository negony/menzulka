/// Типы событий журнала проекта.
class HistoryEventType {
  static const annotationCreated = 'annotation_created';
  static const annotationUpdated = 'annotation_updated';
  static const annotationDeleted = 'annotation_deleted';
  static const annotationRestored = 'annotation_restored';
  static const photoAdded = 'photo_added';
  static const photoRemoved = 'photo_removed';
  static const audioAdded = 'audio_added';
  static const audioRemoved = 'audio_removed';
  static const measurementCreated = 'measurement_created';
  static const measurementDeleted = 'measurement_deleted';
  static const projectExported = 'project_exported';
  static const projectImported = 'project_imported';
  static const dxfExported = 'dxf_exported';
  static const dwgExported = 'dwg_exported';
  static const versionCreated = 'version_created';
  static const versionRestored = 'version_restored';
}

/// Категория события для фильтров журнала.
enum HistoryCategory { points, photos, audio, measurements, system }

const Map<HistoryCategory, List<String>> historyCategoryTypes = {
  HistoryCategory.points: [
    HistoryEventType.annotationCreated,
    HistoryEventType.annotationUpdated,
    HistoryEventType.annotationDeleted,
    HistoryEventType.annotationRestored,
  ],
  HistoryCategory.photos: [
    HistoryEventType.photoAdded,
    HistoryEventType.photoRemoved,
  ],
  HistoryCategory.audio: [
    HistoryEventType.audioAdded,
    HistoryEventType.audioRemoved,
  ],
  HistoryCategory.measurements: [
    HistoryEventType.measurementCreated,
    HistoryEventType.measurementDeleted,
  ],
  HistoryCategory.system: [
    HistoryEventType.dxfExported,
    HistoryEventType.dwgExported,
    HistoryEventType.projectExported,
    HistoryEventType.projectImported,
    HistoryEventType.versionCreated,
    HistoryEventType.versionRestored,
  ],
};

/// Одно событие журнала проекта.
class HistoryEvent {
  final String id;
  final String drawingId;
  final String? annotationId;
  final String type;
  final String summary;
  final String? detailsJson;
  final DateTime createdAt;

  HistoryEvent({
    required this.id,
    required this.drawingId,
    this.annotationId,
    required this.type,
    required this.summary,
    this.detailsJson,
    required this.createdAt,
  });
}
