import '../utils/format_utils.dart';

/// Снимок проекта (версия файла `.abris`), сохранённый локально.
class ProjectVersion {
  final String id;
  final String drawingId;
  final String label;
  final String filePath;
  final int sizeBytes;
  final int annotationsCount;
  final int measurementsCount;
  final int photosCount;
  final int audioCount;
  final DateTime createdAt;

  ProjectVersion({
    required this.id,
    required this.drawingId,
    required this.label,
    required this.filePath,
    required this.sizeBytes,
    this.annotationsCount = 0,
    this.measurementsCount = 0,
    this.photosCount = 0,
    this.audioCount = 0,
    required this.createdAt,
  });

  /// Понятная строка состава версии.
  String get contentsLabel {
    final parts = <String>[
      '$annotationsCount ${plural(annotationsCount, 'точка', 'точки', 'точек')}',
    ];
    if (photosCount > 0) parts.add('$photosCount фото');
    if (audioCount > 0) {
      parts.add(
          '$audioCount ${plural(audioCount, 'заметка', 'заметки', 'заметок')}');
    }
    if (measurementsCount > 0) {
      parts.add(
        '$measurementsCount ${plural(measurementsCount, 'измерение', 'измерения', 'измерений')}',
      );
    }
    return parts.join(' · ');
  }
}
