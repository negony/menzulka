import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Выбор фотографии из проводника (ПК) или системного файлового менеджера
/// (Android). Возвращает локальный файл с изображением либо null.
Future<File?> pickPhotoFromFiles() async {
  const group = XTypeGroup(
    label: 'Изображения',
    extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'heic', 'heif'],
    mimeTypes: ['image/*', 'application/octet-stream'],
    uniformTypeIdentifiers: ['public.image'],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return saveTempImage(bytes, suggestedName: file.name);
}

/// Сохраняет байты изображения во временный файл (для последующей записи в БД).
Future<File> saveTempImage(
  Uint8List bytes, {
  required String suggestedName,
}) async {
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final sourceExt = p.extension(suggestedName).toLowerCase();
  final ext = sourceExt.isEmpty ? '.jpg' : sourceExt;
  final base = p.basenameWithoutExtension(suggestedName);
  final safeBase = base.isEmpty ? 'photo' : base;
  final target = File(p.join(dir.path, 'picked_${stamp}_$safeBase$ext'));
  await target.create(recursive: true);
  await target.writeAsBytes(bytes, flush: true);
  return target;
}

/// Диалог «откуда взять фото»: камера или файл.
/// Возвращает 'camera' / 'file' или null при отмене.
Future<String?> askPhotoSource(
  BuildContext context, {
  bool allowCamera = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Добавить фото'),
      children: [
        if (allowCamera)
          SimpleDialogOption(
            key: const Key('photo-source-camera'),
            onPressed: () => Navigator.pop(ctx, 'camera'),
            child: const ListTile(
              leading: Icon(Icons.photo_camera),
              title: Text('Сфотографировать'),
              subtitle: Text('камера устройства'),
            ),
          ),
        SimpleDialogOption(
          key: const Key('photo-source-file'),
          onPressed: () => Navigator.pop(ctx, 'file'),
          child: const ListTile(
            leading: Icon(Icons.folder_open),
            title: Text('Выбрать из файла'),
            subtitle: Text('проводник / галерея'),
          ),
        ),
      ],
    ),
  );
}
