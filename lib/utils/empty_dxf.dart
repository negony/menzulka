import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Встроенный эталонный пустой чертёж (настоящий DXF, сохранённый AutoCAD 2013,
/// `$ACADVER = AC1027`) — основа для кнопки «Создать чертёж».
///
/// В файле есть все разделы (HEADER, CLASSES, TABLES, BLOCKS, ENTITIES, OBJECTS,
/// ACDSDATA), поэтому он открывается в AutoCAD, а экспорт из приложения не даёт
/// ошибок вида «Ошибка в таблице APPID» и «Недопустимое имя элемента таблицы».
const String kEmptyDxfAsset = 'assets/empty.dxf';

/// Загружает байты эталонного пустого DXF без изменений.
Future<Uint8List> loadEmptyDxfTemplate() async {
  final data = await rootBundle.load(kEmptyDxfAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
