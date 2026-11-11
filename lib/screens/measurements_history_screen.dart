import 'package:flutter/material.dart';
import '../models/measurement.dart';
import '../services/database.dart';
import 'measurement_detail_screen.dart';

class MeasurementsHistoryScreen extends StatefulWidget {
  const MeasurementsHistoryScreen({super.key});
  @override
  State<MeasurementsHistoryScreen> createState() =>
      _MeasurementsHistoryScreenState();
}

class _MeasurementsHistoryScreenState extends State<MeasurementsHistoryScreen> {
  final _db = DatabaseService.instance;
  String _filter = 'all';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await _db.deleteMeasurements(_selectedIds.toList());
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все измерения будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Очистить')),
        ],
      ),
    );
    if (confirm == true) await _db.clearAllMeasurements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История измерений'),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
                icon: const Icon(Icons.delete), onPressed: _deleteSelected),
            TextButton(
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
              child: const Text('Отмена'),
            ),
          ] else
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') _clearAll();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'clear', child: Text('Очистить историю')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilterChip(
                    label: const Text('Все'),
                    selected: _filter == 'all',
                    onSelected: (s) {
                      if (s) setState(() => _filter = 'all');
                    }),
                const SizedBox(width: 8),
                FilterChip(
                    label: const Text('Расстояния'),
                    selected: _filter == 'distance',
                    onSelected: (s) {
                      if (s) setState(() => _filter = 'distance');
                    }),
                const SizedBox(width: 8),
                FilterChip(
                    label: const Text('Контуры'),
                    selected: _filter == 'polygon',
                    onSelected: (s) {
                      if (s) setState(() => _filter = 'polygon');
                    }),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Measurement>>(
              stream: _db.watchMeasurements(filter: _filter),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет измерений'),
                      ],
                    ),
                  );
                }
                final measurements = snapshot.data!;
                return ListView.builder(
                  itemCount: measurements.length,
                  itemBuilder: (context, index) {
                    final m = measurements[index];
                    return Dismissible(
                      key: Key(m.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        await _db.deleteMeasurement(m.id);
                        return true;
                      },
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: _selectedIds.contains(m.id),
                                onChanged: (_) => _toggleSelection(m.id))
                            : Icon(
                                m is DistanceMeasurement
                                    ? Icons.straighten
                                    : ((m as PolygonMeasurement).closed
                                        ? Icons.crop_square
                                        : Icons.polyline),
                                color: Colors.orange,
                                size: 32),
                        title: Text(m is DistanceMeasurement
                            ? 'Расстояние'
                            : ((m as PolygonMeasurement).closed
                                ? 'Полигон'
                                : 'Ломаная')),
                        subtitle: Text(m.formatResult('m')),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(m.id);
                          } else {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MeasurementDetailScreen(measurement: m),
                                ));
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
