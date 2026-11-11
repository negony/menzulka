import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Простые настройки приложения, сохраняемые в JSON-файл и переживающие
/// перезапуск (порядок инструментов рисования и т.п.).
class AppPrefs {
  AppPrefs._();

  static final AppPrefs instance = AppPrefs._();

  /// Каталог настроек (в тестах подменяется временным).
  String? overrideDirectory;

  static const String _fileName = 'app_prefs.json';

  List<String> _drawToolOrder = const [];

  /// Порядок инструментов рисования (имена DrawnType), как сохранён.
  List<String> get drawToolOrder => List<String>.unmodifiable(_drawToolOrder);

  File? _file;

  Future<File> _resolveFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final Directory dir;
    if (overrideDirectory != null) {
      dir = Directory(overrideDirectory!);
    } else {
      dir = await getApplicationSupportDirectory();
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, _fileName));
    _file = file;
    return file;
  }

  Future<void> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is Map) {
        final order = data['drawToolOrder'];
        if (order is List) {
          _drawToolOrder = [
            for (final e in order)
              if (e is String) e,
          ];
        }
      }
    } catch (_) {
      // повреждённый файл — остаёмся на значениях по умолчанию
    }
  }

  Future<void> save() async {
    try {
      final file = await _resolveFile();
      await file.writeAsString(jsonEncode({
        'drawToolOrder': _drawToolOrder,
      }));
    } catch (_) {
      // настройки не критичны для работы приложения
    }
  }

  Future<void> setDrawToolOrder(List<String> order) async {
    _drawToolOrder = List<String>.of(order);
    await save();
  }

  /// Сброс состояния (для тестов).
  void resetForTests() {
    _drawToolOrder = const [];
    _file = null;
    overrideDirectory = null;
  }
}
