import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/annotation.dart';
import '../models/audio_note.dart';
import '../models/history_event.dart';
import '../models/photo.dart';
import '../models/photo_annotation.dart';
import '../services/database.dart';
import '../utils/format_utils.dart';
import '../utils/photo_picker.dart';
import '../widgets/audio_notes_editor.dart';
import 'photo_view_screen.dart';

class AnnotationDetailScreen extends StatefulWidget {
  final Annotation annotation;

  /// Единицы чертежа — для подписи координат.
  final String units;
  const AnnotationDetailScreen(
      {super.key, required this.annotation, this.units = 'm'});
  @override
  State<AnnotationDetailScreen> createState() => _AnnotationDetailScreenState();
}

class _AnnotationDetailScreenState extends State<AnnotationDetailScreen> {
  final _db = DatabaseService.instance;
  late Annotation _annotation;
  bool _isEditing = false;
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();

  /// Номер точки — редактируется в режиме правки.
  final _numberController = TextEditingController();
  final _dxfXController = TextEditingController();
  final _dxfYController = TextEditingController();
  final _geoZController = TextEditingController();
  List<Photo> _photos = [];
  List<AudioNote> _audio = [];
  List<HistoryEvent> _pointHistory = [];

  /// Счётчик изменений фото: заставляет миниатюры перезапрашивать файл.
  int _photosRevision = 0;

  @override
  void initState() {
    super.initState();
    _annotation = widget.annotation;
    _descriptionController.text = _annotation.description ?? '';
    _codeController.text = _annotation.code ?? '';
    _numberController.text = _annotation.number.toString();
    _dxfXController.text = _annotation.dxfX.toStringAsFixed(3);
    _dxfYController.text = _annotation.dxfY.toStringAsFixed(3);
    _geoZController.text = _annotation.geoZ?.toString() ?? '';
    _photos = List.of(_annotation.photos);
    _audio = List.of(_annotation.audioNotes);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final events = await _db.getHistoryForAnnotation(_annotation.id, limit: 30);
    if (mounted) setState(() => _pointHistory = events);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _codeController.dispose();
    _numberController.dispose();
    _dxfXController.dispose();
    _dxfYController.dispose();
    _geoZController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = _annotation.copyWith(
      number: int.tryParse(_numberController.text.trim()) ?? _annotation.number,
      code: _codeController.text.isEmpty ? null : _codeController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      dxfX: double.tryParse(_dxfXController.text) ?? _annotation.dxfX,
      dxfY: double.tryParse(_dxfYController.text) ?? _annotation.dxfY,
      geoZ: double.tryParse(_geoZController.text),
      photos: List.of(_photos),
      audioNotes: List.of(_audio),
      updatedAt: DateTime.now(),
    );
    await _db.updateAnnotation(updated);
    await _db.replacePhotos(_annotation.id, _photos);
    await _db.replaceAudioNotes(_annotation.id, _audio);
    await _loadHistory();
    setState(() {
      _annotation = updated;
      _isEditing = false;
    });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аннотацию?'),
        content: Text('Точка №${_annotation.number} будет удалена.'),
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
      await _db.deleteAnnotation(_annotation.id);
      if (mounted) Navigator.pop(context);
    }
  }

  /// «Добавить фото»: камера или выбор файла из проводника.
  Future<void> _addPhoto() async {
    final source = await askPhotoSource(context);
    if (source == null || !mounted) return;
    String? path;
    if (source == 'camera') {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      path = image?.path;
    } else {
      final file = await pickPhotoFromFiles();
      path = file?.path;
    }
    if (path == null || !mounted) return;
    // сразу копируем во постоянное хранилище приложения
    final saved = await _db.savePhotoFile(path);
    if (!mounted) return;
    setState(() => _photos.add(Photo(
          id: const Uuid().v4(),
          annotationId: _annotation.id,
          localFilePath: saved,
          createdAt: DateTime.now(),
        )));
  }

  /// Открывает фото на весь экран; если пользователь сохранил рисунок
  /// отдельным файлом — добавляет его в точку.
  Future<void> _openPhoto(int index) async {
    final current = _photos[index];
    final result = await Navigator.push<PhotoEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewScreen(imagePath: current.localFilePath),
      ),
    );
    if (!mounted || result == null) return;
    if (result.replaced) {
      await FileImage(File(result.path)).evict();
      if (!mounted) return;
      // Новый ключ миниатюры: провайдер с тем же путём считается равным и
      // без этого не перезапрашивает картинку (превью оставалось старым).
      setState(() => _photosRevision++);
      return;
    }
    final saved = await _db.savePhotoFile(result.path);
    if (!mounted) return;
    setState(() {
      _photos.add(Photo(
        id: const Uuid().v4(),
        annotationId: _annotation.id,
        localFilePath: saved,
        createdAt: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Точка №${_annotation.number}'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.save), onPressed: _save)
          else
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _isEditing = true)),
          IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
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
                  const Text('Координаты',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isEditing) ...[
                    TextField(
                      key: const Key('detail-point-number'),
                      controller: _numberController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Номер точки'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('detail-point-x'),
                            controller: _dxfXController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: InputDecoration(
                              labelText: 'X',
                              suffixText: unitsLabel(widget.units),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('detail-point-y'),
                            controller: _dxfYController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: InputDecoration(
                              labelText: 'Y',
                              suffixText: unitsLabel(widget.units),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _geoZController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Высота Z'),
                    ),
                  ] else ...[
                    Text(
                        'X: ${formatCoordinate(_annotation.dxfX)} ${unitsLabel(widget.units)}'),
                    Text(
                        'Y: ${formatCoordinate(_annotation.dxfY)} ${unitsLabel(widget.units)}'),
                    if (_annotation.geoZ != null)
                      Text('Z: ${formatCoordinate(_annotation.geoZ!)}'),
                  ],
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
                  const Text('Код',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(controller: _codeController)
                  else
                    Text(_annotation.code ?? '(не указан)'),
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
                  const Text('Описание',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(controller: _descriptionController, maxLines: 3)
                  else
                    Text(_annotation.description ?? '(не указано)'),
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
                  Row(
                    children: [
                      const Text('Фото',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_isEditing)
                        IconButton(
                            icon: const Icon(Icons.add_a_photo),
                            onPressed: _addPhoto),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_photos.isEmpty)
                    const Text('Нет фотографий')
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            key: ValueKey(
                                'detail-photo-${_photos[index].id}-$_photosRevision'),
                            // Container с одной картинкой без child не участвует
                            // в hit-testing — opaque гарантирует приём тапа.
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openPhoto(index),
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(
                                      File(_photos[index].localFilePath)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
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
              child: AudioNotesEditor(
                notes: _audio,
                annotationId: _annotation.id,
                enabled: _isEditing,
                onChanged: (list) => setState(() => _audio = list),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: Text(
                'История точки (${_pointHistory.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: _pointHistory.isEmpty
                  ? const [
                      ListTile(
                        dense: true,
                        title: Text('Изменений пока нет'),
                      ),
                    ]
                  : [
                      for (final event in _pointHistory)
                        ListTile(
                          dense: true,
                          title: Text(event.summary),
                          subtitle: Text(
                            '${formatHistoryDate(event.createdAt)} '
                            '${formatHistoryTime(event.createdAt)}',
                          ),
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
