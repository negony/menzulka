import 'package:flutter/material.dart';
import '../models/annotation.dart';
import '../services/database.dart';
import 'annotation_detail_screen.dart';

class AnnotationsListScreen extends StatefulWidget {
  final String drawingId;
  final String drawingName;
  const AnnotationsListScreen(
      {super.key, required this.drawingId, required this.drawingName});
  @override
  State<AnnotationsListScreen> createState() => _AnnotationsListScreenState();
}

class _AnnotationsListScreenState extends State<AnnotationsListScreen> {
  final _searchController = TextEditingController();
  final _db = DatabaseService.instance;
  String _searchQuery = '';
  String _filter = 'all';
  final String _sortBy = 'number';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  /// Единицы чертежа — для подписи координат на экране точки.
  String _units = 'm';

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final drawing = await _db.getDrawingById(widget.drawingId);
    if (drawing != null && mounted) {
      setState(() => _units = drawing.units);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные?'),
        content: Text('Будет удалено: ${_selectedIds.length}'),
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
      await _db.deleteAnnotations(_selectedIds.toList());
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.drawingName),
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
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    label: const Text('С кодом'),
                    selected: _filter == 'with_code',
                    onSelected: (s) {
                      if (s) setState(() => _filter = 'with_code');
                    }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Annotation>>(
              stream: _db.watchAnnotations(
                drawingId: widget.drawingId,
                searchQuery: _searchQuery,
                filter: _filter,
                sortBy: _sortBy,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Аннотации не найдены'));
                }
                final annotations = snapshot.data!;
                return ListView.builder(
                  itemCount: annotations.length,
                  itemBuilder: (context, index) {
                    final ann = annotations[index];
                    final isSelected = _selectedIds.contains(ann.id);
                    return Dismissible(
                      key: Key(ann.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        await _db.deleteAnnotation(ann.id);
                        if (!context.mounted) return true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Точка №${ann.number} удалена'),
                            action: SnackBarAction(
                              label: 'Отмена',
                              onPressed: () => _db.restoreAnnotation(ann.id),
                            ),
                          ),
                        );
                        return true;
                      },
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(ann.id))
                            : CircleAvatar(child: Text('${ann.number}')),
                        title: Text(ann.code ?? '(нет кода)'),
                        subtitle: Text(ann.description ?? '(нет описания)'),
                        trailing: (ann.photos.isEmpty && ann.audioNotes.isEmpty)
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (ann.photos.isNotEmpty)
                                    const Icon(Icons.photo_camera, size: 16),
                                  if (ann.photos.isNotEmpty &&
                                      ann.audioNotes.isNotEmpty)
                                    const SizedBox(width: 8),
                                  if (ann.audioNotes.isNotEmpty)
                                    const Icon(Icons.mic, size: 16),
                                ],
                              ),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(ann.id);
                          } else {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnnotationDetailScreen(
                                      annotation: ann, units: _units),
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
