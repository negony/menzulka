import 'dart:io';
import 'package:flutter/material.dart';

import '../models/photo_annotation.dart';
import 'photo_annotator_screen.dart';

/// Полноэкранный просмотр фотографии с зумом и переходом к рисованию.
///
/// Возвращает [PhotoEditResult], если пользователь изменил фото: рисунок
/// поверх («заменено») или новое фото-копия (тогда вызывающий добавляет его).
class PhotoViewScreen extends StatefulWidget {
  final String imagePath;
  const PhotoViewScreen({super.key, required this.imagePath});

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late String _path = widget.imagePath;
  int _revision = 0;

  /// Что вернуть вызывающему экрану при выходе (если фото менялось).
  PhotoEditResult? _pending;

  Future<void> _draw() async {
    final result = await Navigator.push<PhotoEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoAnnotatorScreen(imagePath: _path),
      ),
    );
    if (!mounted || result == null) return;
    if (result.replaced) {
      // Файл перезаписан по тому же пути — сбрасываем кэш картинки.
      await FileImage(File(result.path)).evict();
      if (!mounted) return;
      setState(() {
        _path = result.path;
        _revision++;
        _pending = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Рисунок сохранён на фото')),
      );
    } else {
      // Новый файл — отдаём вызывающему экрану, чтобы он добавил его в точку.
      Navigator.pop(context, result);
    }
  }

  void _goBack() => Navigator.pop(context, _pending);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // При системном «назад» возвращаем результат, если фото менялось.
      canPop: _pending == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _pending);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: BackButton(onPressed: _goBack),
          title: const Text('Фото'),
          actions: [
            IconButton(
              key: const Key('photo-view-draw'),
              tooltip: 'Рисовать на фото',
              icon: const Icon(Icons.draw),
              onPressed: _draw,
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 6.0,
            child: Image.file(
              File(_path),
              key: ValueKey('${_path}_$_revision'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'Не удалось открыть фото',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('photo-view-draw-fab'),
          onPressed: _draw,
          icon: const Icon(Icons.brush),
          label: const Text('Рисовать'),
        ),
      ),
    );
  }
}
