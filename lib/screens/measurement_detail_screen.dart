import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/measurement.dart';
import '../services/database.dart';

class MeasurementDetailScreen extends StatelessWidget {
  final Measurement measurement;
  const MeasurementDetailScreen({super.key, required this.measurement});

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить измерение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.deleteMeasurement(measurement.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(measurement is DistanceMeasurement
            ? 'Расстояние'
            : ((measurement as PolygonMeasurement).closed
                ? 'Полигон'
                : 'Ломаная')),
        actions: [
          IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _delete(context)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Результат',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(measurement.formatResult('m'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  if (measurement is PolygonMeasurement)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        (measurement as PolygonMeasurement).closed
                            ? 'Контур замкнут'
                            : 'Контур открыт',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Точки',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (measurement is DistanceMeasurement) ...[
                    _pointTile(
                        'Точка 1', (measurement as DistanceMeasurement).point1),
                    const Divider(),
                    _pointTile(
                        'Точка 2', (measurement as DistanceMeasurement).point2),
                  ] else if (measurement is PolygonMeasurement) ...[
                    for (int i = 0;
                        i < (measurement as PolygonMeasurement).points.length;
                        i++) ...[
                      _pointTile('Точка ${i + 1}',
                          (measurement as PolygonMeasurement).points[i]),
                      if (i <
                          (measurement as PolygonMeasurement).points.length - 1)
                        const Divider(),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointTile(String label, ui.Offset point) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Text('X: ${point.dx.toStringAsFixed(3)}'),
          const SizedBox(width: 16),
          Text('Y: ${point.dy.toStringAsFixed(3)}'),
        ],
      ),
    );
  }
}
