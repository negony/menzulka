import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/screens/photo_annotator_screen.dart';
import 'package:image/image.dart' as img;

/// Тестовая фотография 200×150 (генерируется пакетом `image`, чтобы не
/// зависеть от внешних файлов и «магических» base64-строк).
Future<File> _makePhoto() async {
  final picture = img.Image(width: 200, height: 150);
  img.fill(picture, color: img.ColorRgb8(180, 200, 220));
  img.fillRect(picture,
      x1: 20, y1: 20, x2: 180, y2: 130, color: img.ColorRgb8(90, 120, 160));
  final dir = await Directory.systemTemp.createTemp('photo_annotator_test');
  final file = File('${dir.path}/photo.png');
  await file.writeAsBytes(img.encodePng(picture));
  return file;
}

Future<void> _pumpScreen(WidgetTester tester, File photo) async {
  // Декодирование изображения в тестах не нужно: экран принимает размер кадра
  // напрямую, а фон рисуется заглушкой.
  await tester.pumpWidget(MaterialApp(
    home: PhotoAnnotatorScreen(
      imagePath: photo.path,
      debugImageSize: const Size(200, 150),
    ),
  ));
  await tester.pump();
  expect(find.byKey(const Key('photo-annotator-canvas')), findsOneWidget,
      reason: 'холст должен быть доступен сразу');
}

Finder _canvas() => find.byKey(const Key('photo-annotator-canvas'));

IconButton _appBarButton(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key)));

void main() {
  late File photo;

  setUp(() async {
    photo = await _makePhoto();
  });

  tearDown(() async {
    final dir = photo.parent;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Windows может держать файл открытым — временная папка не критична.
    }
  });

  testWidgets('открывается и показывает все инструменты', (tester) async {
    await _pumpScreen(tester, photo);

    expect(find.text('Рисование'), findsOneWidget);
    for (final tool in ['pencil', 'line', 'rect', 'circle', 'arrow', 'text']) {
      expect(find.byKey(Key('photo-tool-$tool')), findsOneWidget);
    }
    expect(find.text('Карандаш'), findsOneWidget);
    expect(find.text('Текст'), findsOneWidget);
    expect(_appBarButton(tester, 'photo-undo').onPressed, isNull);
    expect(_appBarButton(tester, 'photo-clear').onPressed, isNull);
  });

  testWidgets('линия рисуется и удаляется кнопкой «Отменить»', (tester) async {
    await _pumpScreen(tester, photo);

    await tester.tap(find.byKey(const Key('photo-tool-line')));
    await tester.pump();
    expect(_appBarButton(tester, 'photo-undo').onPressed, isNull);

    await tester.drag(_canvas(), const Offset(120, 40));
    await tester.pumpAndSettle();

    expect(_appBarButton(tester, 'photo-undo').onPressed, isNotNull);
    expect(find.text('Отменить (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-undo')));
    await tester.pumpAndSettle();
    expect(find.text('Отменить (0)'), findsOneWidget);
    expect(_appBarButton(tester, 'photo-undo').onPressed, isNull);
  });

  testWidgets('ластик удаляет нарисованный объект по нажатию', (tester) async {
    await _pumpScreen(tester, photo);

    // Рисуем линию через центр холста.
    await tester.tap(find.byKey(const Key('photo-tool-line')));
    await tester.pump();
    final center = tester.getCenter(_canvas());
    await tester.drag(_canvas(), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Отменить (1)'), findsOneWidget);

    // Включаем ластик и нажимаем на линию.
    await tester.tap(find.byKey(const Key('photo-erase-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Ластик включён'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.text('Отменить (0)'), findsOneWidget);

    // Повторное нажатие по пустому месту ничего не ломает.
    await tester.tapAt(center + const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(find.text('Отменить (0)'), findsOneWidget);
  });

  testWidgets('текст добавляется через диалог', (tester) async {
    await _pumpScreen(tester, photo);

    await tester.tap(find.byKey(const Key('photo-tool-text')));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(_canvas()));
    await tester.pumpAndSettle();

    expect(find.text('Текст на фото'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('photo-text-field')), 'ЛЮК-1');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();

    expect(find.text('Отменить (1)'), findsOneWidget);
  });

  testWidgets('«Очистить» удаляет все объекты после подтверждения',
      (tester) async {
    await _pumpScreen(tester, photo);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('photo-tool-rect')));
      await tester.pump();
      await tester.drag(_canvas(), Offset(40.0 + i * 10, 40));
      await tester.pumpAndSettle();
    }
    expect(find.text('Отменить (2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Очистить рисунок?'), findsOneWidget);
    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить (0)'), findsOneWidget);
  });

  testWidgets('сохранение открывает выбор «заменить / копия»', (tester) async {
    await _pumpScreen(tester, photo);

    await tester.tap(find.byKey(const Key('photo-tool-line')));
    await tester.pump();
    await tester.drag(_canvas(), const Offset(60, 30));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('photo-save')));
    await tester.pumpAndSettle();

    expect(find.text('Сохранить рисунок'), findsOneWidget);
    expect(find.text('Заменить фото'), findsOneWidget);
    expect(find.text('Сохранить как новое фото'), findsOneWidget);
  });
}
