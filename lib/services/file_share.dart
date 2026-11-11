import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Делится файлом на мобильных (share sheet) или предлагает сохранить на ПК.
/// Возвращает путь сохранения на ПК; null — отмена или «поделиться».
///
/// [mimeType] важен для «экзотических» форматов: пакет `mime` определяет `.dxf`
/// как `image/vnd.dxf`, из-за чего Telegram принимает файл за картинку и
/// переименовывает в `IMG_…jpg`. Передаём `application/octet-stream`, чтобы
/// файл уходил документом с исходным именем.
Future<String?> shareOrSaveFile(
  String path, {
  String text = 'Проект абриса',
  String? mimeType,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final name = p.basename(path);
    await Share.shareXFiles(
      [XFile(path, mimeType: mimeType)],
      text: text,
      fileNameOverrides: [name],
    );
    return null;
  }
  final location = await getSaveLocation(suggestedName: p.basename(path));
  if (location == null) return null;
  if (p.normalize(location.path) == p.normalize(path)) return location.path;
  await File(path).copy(location.path);
  return location.path;
}
