import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Встроенный эталонный пустой чертёж — чистый DXF, сохранённый AutoCAD 2013
/// (`$ACADVER = AC1027`, метры), основа для кнопки «Создать чертёж».
///
/// В файле есть все разделы (HEADER, CLASSES, TABLES, BLOCKS, ENTITIES, OBJECTS),
/// поэтому он открывается в AutoCAD, а экспорт не даёт ошибок вида «Ошибка в
/// таблице APPID» и «Недопустимое имя элемента таблицы».
///
/// Важно: в шаблоне **нет** объектов Civil 3D/AEC (`AECC_*`, `AeccDb*`) — именно
/// они раньше мешали записывать DWG (writer не умеет их кодировать).
const String kEmptyDxfAsset = 'assets/empty.dxf';

/// Загружает байты эталонного пустого DXF без изменений.
Future<Uint8List> loadEmptyDxfTemplate() async {
  final data = await rootBundle.load(kEmptyDxfAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
