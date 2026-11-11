import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/annotation.dart';
import '../models/audio_note.dart';
import '../models/photo.dart';
import '../models/photo_annotation.dart';
import '../utils/format_utils.dart';
import '../utils/photo_picker.dart';
import '../widgets/audio_notes_editor.dart';
import 'photo_view_screen.dart';

class CreateAnnotationSheet extends StatefulWidget {
  final String drawingId;
  final double dxfX;
  final double dxfY;
  final int annotationNumber;
  final Function(Annotation) onSaved;

  /// Единицы чертежа — для подписи координат.
  final String units;
  const CreateAnnotationSheet({
    super.key,
    required this.drawingId,
    required this.dxfX,
    required this.dxfY,
    required this.annotationNumber,
    required this.onSaved,
    this.units = 'm',
  });
  @override
  State<CreateAnnotationSheet> createState() => _CreateAnnotationSheetState();
}

class _CreateAnnotationSheetState extends State<CreateAnnotationSheet> {
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  // Номер точки — можно изменить при создании.
  late final _numberController =
      TextEditingController(text: widget.annotationNumber.toString());
  // Координаты точки в системе чертежа (совпадает с DXF) — редактируемые.
  late final _xController =
      TextEditingController(text: widget.dxfX.toStringAsFixed(3));
  late final _yController =
      TextEditingController(text: widget.dxfY.toStringAsFixed(3));
  final _geoZController = TextEditingController();
  final List<File> _photos = [];
  List<AudioNote> _audio = [];
  bool _isSaving = false;
  bool _showDetails = true;

  /// Счётчик изменений фото: заставляет миниатюры перезапрашивать файл.
  int _photosRevision = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    _codeController.dispose();
    _numberController.dispose();
    _xController.dispose();
    _yController.dispose();
    _geoZController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image != null) setState(() => _photos.add(File(image.path)));
  }

  /// Кнопка «Добавить фото»: камера или проводник.
  Future<void> _addPhoto() async {
    final source = await askPhotoSource(context);
    if (source == null || !mounted) return;
    if (source == 'camera') {
      await _takePhoto();
      return;
    }
    final file = await pickPhotoFromFiles();
    if (file == null || !mounted) return;
    setState(() => _photos.add(file));
  }

  /// Просмотр фото точки с возможностью рисования; новое фото добавляется
  /// к карточке, изменённое — обновляется на месте.
  Future<void> _openPhoto(int index) async {
    final result = await Navigator.push<PhotoEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewScreen(imagePath: _photos[index].path),
      ),
    );
    if (!mounted || result == null) return;
    if (result.replaced) {
      await FileImage(File(result.path)).evict();
      if (!mounted) return;
      // Новый ключ элемента — иначе Flutter считает провайдер тем же и
      // превью не перезапрашивается (остаётся старая картинка).
      setState(() => _photosRevision++);
      return;
    }
    setState(() => _photos.add(File(result.path)));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      const uuid = Uuid();
      final annotationId = uuid.v4();
      final photos = _photos
          .map((f) => Photo(
                id: uuid.v4(),
                annotationId: annotationId,
                localFilePath: f.path,
                createdAt: DateTime.now(),
              ))
          .toList();
      final annotation = Annotation(
        id: annotationId,
        drawingId: widget.drawingId,
        number: int.tryParse(_numberController.text.trim()) ??
            widget.annotationNumber,
        dxfX: double.tryParse(_xController.text) ?? widget.dxfX,
        dxfY: double.tryParse(_yController.text) ?? widget.dxfY,
        geoZ: double.tryParse(_geoZController.text),
        code: _codeController.text.isEmpty ? null : _codeController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        photos: photos,
        audioNotes: List.of(_audio),
        createdAt: DateTime.now(),
      );
      widget.onSaved(annotation);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        // Material (а не Container с цветом): внутри ExpansionTile/ListTile,
        // которым нужен ближайший Material для фона и чернил.
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Точка №',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        key: const Key('point-number'),
                        controller: _numberController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Фото',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _photos.length) {
                            return GestureDetector(
                              onTap: _addPhoto,
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo,
                                        size: 32, color: Colors.grey),
                                    SizedBox(height: 4),
                                    Text('Добавить'),
                                  ],
                                ),
                              ),
                            );
                          }
                          return GestureDetector(
                            key:
                                ValueKey('sheet-photo-$index-$_photosRevision'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openPhoto(index),
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(_photos[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AudioNotesEditor(
                      notes: _audio,
                      annotationId: '',
                      onChanged: (list) => setState(() => _audio = list),
                    ),
                    const SizedBox(height: 16),
                    const Text('Код',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        hintText: 'Например: ЛЮК_К',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Описание'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Описание объекта...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      title: const Text('Координаты и детали'),
                      initiallyExpanded: _showDetails,
                      onExpansionChanged: (v) =>
                          setState(() => _showDetails = v),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Координаты точки в системе чертежа (совпадает с DXF).
                              // Предзаполнены с чертежа, но пользователь может изменить.
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const Key('point-x'),
                                      controller: _xController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
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
                                      key: const Key('point-y'),
                                      controller: _yController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
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
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Высота Z'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56)),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56)),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
