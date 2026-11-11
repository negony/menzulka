import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/services/app_prefs.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('app_prefs_test');
    AppPrefs.instance.resetForTests();
    AppPrefs.instance.overrideDirectory = dir.path;
  });

  tearDown(() {
    AppPrefs.instance.resetForTests();
    dir.deleteSync(recursive: true);
  });

  test('порядок инструментов сохраняется и загружается', () async {
    await AppPrefs.instance
        .setDrawToolOrder(['line', 'point', 'polyline', 'text']);
    expect(
        AppPrefs.instance.drawToolOrder, ['line', 'point', 'polyline', 'text']);

    // «Перезапуск»: сбрасываем кэш и читаем файл заново.
    final saved = File('${dir.path}/app_prefs.json');
    expect(saved.existsSync(), isTrue);
    AppPrefs.instance.resetForTests();
    AppPrefs.instance.overrideDirectory = dir.path;
    await AppPrefs.instance.load();
    expect(
        AppPrefs.instance.drawToolOrder, ['line', 'point', 'polyline', 'text']);
  });

  test('повреждённый файл не ломает настройки', () async {
    File('${dir.path}/app_prefs.json').writeAsStringSync('{не json');
    AppPrefs.instance.resetForTests();
    AppPrefs.instance.overrideDirectory = dir.path;
    await AppPrefs.instance.load();
    expect(AppPrefs.instance.drawToolOrder, isEmpty);
  });

  test('нет файла — пустой порядок (значения по умолчанию)', () async {
    await AppPrefs.instance.load();
    expect(AppPrefs.instance.drawToolOrder, isEmpty);
  });
}
