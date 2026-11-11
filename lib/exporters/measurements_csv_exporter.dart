import 'dart:io';
import '../models/measurement.dart';

class MeasurementsCsvExporter {
  Future<String> export({
    required List<Measurement> measurements,
    required String outputDirectory,
  }) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('Тип;Результат;Точки;Дата');
    for (final m in measurements) {
      final type = m is DistanceMeasurement
          ? 'Расстояние'
          : ((m as PolygonMeasurement).closed ? 'Полигон' : 'Ломаная');
      final result = m.formatResult('m');
      final points = _formatPoints(m);
      final date = _formatDate(m.createdAt);
      buffer.writeln('$type;$result;$points;$date');
    }
    final fileName =
        'measurements_${DateTime.now().millisecondsSinceEpoch}.csv';
    final filePath = '$outputDirectory/$fileName';
    await File(filePath).writeAsString(buffer.toString());
    return filePath;
  }

  String _formatPoints(Measurement m) {
    if (m is DistanceMeasurement) {
      return '(${m.point1.dx.toStringAsFixed(3)}, ${m.point1.dy.toStringAsFixed(3)}) → '
          '(${m.point2.dx.toStringAsFixed(3)}, ${m.point2.dy.toStringAsFixed(3)})';
    } else if (m is PolygonMeasurement) {
      return m.points
          .map(
              (p) => '(${p.dx.toStringAsFixed(3)}, ${p.dy.toStringAsFixed(3)})')
          .join(' → ');
    }
    return '';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
