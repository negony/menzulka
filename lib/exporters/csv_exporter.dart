import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/annotation.dart';

class CsvExporter {
  Future<String> export({
    required String drawingName,
    required List<Annotation> annotations,
    required String outputDirectory,
  }) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('Номер;X;Y;Z;Код;Описание;Фото;Дата');
    for (final ann in annotations) {
      final row = [
        ann.number.toString(),
        ann.dxfX.toStringAsFixed(3),
        ann.dxfY.toStringAsFixed(3),
        ann.geoZ?.toStringAsFixed(3) ?? '',
        ann.code ?? '',
        _escapeCsvField(ann.description ?? ''),
        ann.photos.isNotEmpty ? p.basename(ann.photos.first.localFilePath) : '',
        _formatDateTime(ann.createdAt),
      ];
      buffer.writeln(row.join(';'));
    }
    final fileName = '${_sanitize(drawingName)}_annotations.csv';
    final filePath = p.join(outputDirectory, fileName);
    await File(filePath).writeAsString(buffer.toString());
    return filePath;
  }

  String _escapeCsvField(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
  }
}
