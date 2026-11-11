import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/annotation.dart';
import 'package:menzulka/models/drawn_object.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/screens/drawing_screen.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/widgets/dxf_viewer.dart';

void main() {
  DxfDocument emptyDoc() => DxfDocument(
        layers: [DxfLayer(name: '0')],
        entities: const [],
        minX: 0,
        minY: 0,
        maxX: 10,
        maxY: 10,
      );

  Future<List<DrawnObject>> pumpViewer(
    WidgetTester tester, {
    DrawingMode mode = DrawingMode.drawing,
    List<DrawnObject> objects = const [],
    VoidCallback? onUndo,
    List<DrawnObject>? updates,
    List<DrawnObject>? deletes,
    Set<String> hiddenDrawnLayers = const {},
    String activeDrawnLayer = kDefaultDrawnLayer,
    SnapSettings? snapSettings,
    List<Annotation> annotations = const [],
    void Function(double x, double y)? onCanvasTap,
    void Function(List<Annotation>, Offset)? onClusterTap,
  }) async {
    final created = <DrawnObject>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: emptyDoc(),
              annotations: annotations,
              hiddenLayers: const {},
              mode: mode,
              units: 'm',
              onCanvasTap: onCanvasTap ?? (_, __) {},
              onAnnotationClusterTap: onClusterTap,
              snapSettings: snapSettings ?? SnapSettings(),
              drawingId: 'd1',
              drawnObjects: objects,
              onDrawnObjectCreated: created.add,
              onUndoLastDrawn: onUndo,
              onDrawnObjectUpdated: updates?.add,
              onDrawnObjectDeleted: deletes?.add,
              hiddenDrawnLayers: hiddenDrawnLayers,
              activeDrawnLayer: activeDrawnLayer,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return created;
  }

  Future<void> selectTool(WidgetTester tester, String name) async {
    final finder = find.byKey(Key('draw-tool-$name'));
    // Строка инструментов теперь прокручиваемая (ReorderableListView) —
    // прокручиваем, пока нужный инструмент не появится.
    if (finder.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        finder,
        find.byKey(const Key('draw-tools')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('панель рисования: инструменты, толщины и цвета', (tester) async {
    await pumpViewer(tester);
    expect(find.text('Точка'), findsOneWidget);
    expect(find.text('Полилиния'), findsOneWidget);
    expect(find.text('Отрезок'), findsOneWidget);
    // Толщины и цвета — в прокручиваемой строке.
    expect(find.byKey(const Key('draw-stroke-1.2')), findsOneWidget);
    expect(find.byKey(const Key('draw-stroke-6.0')), findsOneWidget);
    expect(find.byKey(const Key('draw-color-4294967295')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('точка создаётся с выбранным цветом и толщиной', (tester) async {
    final created = await pumpViewer(tester);
    await tester.tap(find.byKey(const Key('draw-stroke-3.0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('draw-color-4294967295')));
    await tester.pump();
    await selectTool(tester, 'point');
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    final object = created.first;
    expect(object.type, DrawnType.point);
    expect(object.color, 0xFFFFFFFF);
    expect(object.strokePx, 3.0);
    expect(object.points.single.dx, closeTo(5, 0.5));
    expect(object.points.single.dy, closeTo(5, 0.5));
  });

  testWidgets('отрезок — по двум тапам', (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'line');
    await tester.tapAt(const Offset(300, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(500, 300));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    expect(created.first.type, DrawnType.line);
    expect(created.first.points.length, 2);
  });

  testWidgets('полилиния — вершины и «Завершить»', (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'polyline');
    await tester.tapAt(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(500, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(const Key('draw-finish')));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    expect(created.first.type, DrawnType.polyline);
    expect(created.first.points.length, 3);
  });

  testWidgets('размер — по трём точкам', (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'dimension');
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(500, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(450, 250));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    expect(created.first.type, DrawnType.dimension);
    expect(created.first.points.length, 3);
    expect(created.first.height, isNotNull);
    expect(created.first.height! > 0, isTrue);
  });

  testWidgets('текст — диалог и добавление', (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'text');
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Тест');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    expect(created.first.type, DrawnType.text);
    expect(created.first.text, 'Тест');
    expect(created.first.height, isNotNull);
    expect(created.first.height! > 0, isTrue);
  });

  testWidgets('смена режима скрывает панель, объекты остаются', (tester) async {
    final object = DrawnObject(
      id: 'o1',
      drawingId: 'd1',
      type: DrawnType.line,
      points: const [Offset(1, 1), Offset(2, 2)],
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [object], onUndo: () {});
    expect(find.byKey(const Key('draw-tools')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('кнопка «Удалить последний» доступна при наличии объектов',
      (tester) async {
    var undone = 0;
    final object = DrawnObject(
      id: 'o1',
      drawingId: 'd1',
      type: DrawnType.point,
      points: const [Offset(1, 1)],
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester, objects: [object], onUndo: () => undone++);
    await tester.tap(find.byKey(const Key('draw-undo')));
    await tester.pump();
    expect(undone, 1);
  });

  testWidgets('круг: центр тапом, радиус удержанием и скольжением',
      (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'circle');
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(450, 300));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(created.length, 1);
    expect(created.first.type, DrawnType.circle);
    expect(created.first.points.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('облако — свободное рисование пальцем', (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'cloud');

    final gesture = await tester.startGesture(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 600));
    for (final delta in const [
      Offset(40, 0),
      Offset(30, 20),
      Offset(0, 40),
      Offset(-40, 20),
      Offset(-30, -20),
      Offset(0, -40),
    ]) {
      await gesture.moveBy(delta);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(created.length, 1);
    expect(created.first.type, DrawnType.cloud);
    expect(created.first.points.length, greaterThanOrEqualTo(8));
    expect(created.first.bulges.length, created.first.points.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('высота текста выбирается в диалоге текста', (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'text');
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    // Высота — в диалоге ввода текста.
    await tester.tap(find.byKey(const Key('text-height-24.0')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'А');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();

    expect(created.length, 1);
    // Масштаб вписывания: 0.9 * min(800, 600) / 10 = 54.
    expect(created.first.height, closeTo(24 / 54, 0.01));
  });

  testWidgets('текст выбирается и перемещается удержанием', (tester) async {
    final updates = <DrawnObject>[];
    final text = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(5, 5)],
      text: 'А',
      height: 14 / 54,
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [text], updates: updates);

    // Тап по тексту — выбор; протаскивание — перемещение.
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 300), const Offset(108, 0));
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.points.first.dx, closeTo(7, 0.5));
    expect(updates.last.points.first.dy, closeTo(5, 0.5));
  });

  testWidgets('перемещение текста не «улетает» на нескольких move-событиях',
      (tester) async {
    final updates = <DrawnObject>[];
    final text = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(5, 5)],
      text: 'А',
      height: 14 / 54,
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [text], updates: updates);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    // 100 px при масштабе 54 = +1.85 мировых единиц (без накопления сдвига).
    expect(updates, isNotEmpty);
    expect(updates.last.points.first.dx, closeTo(5 + 100 / 54, 0.5));
  });

  testWidgets('текст поворачивается двумя пальцами', (tester) async {
    final updates = <DrawnObject>[];
    final text = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(5, 5)],
      text: 'А',
      height: 14 / 54,
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [text], updates: updates);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    final g1 = await tester.startGesture(const Offset(380, 300));
    final g2 = await tester.startGesture(const Offset(420, 300));
    await tester.pump();
    await g1.moveTo(const Offset(400, 280));
    await g2.moveTo(const Offset(400, 320));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.rotation.abs(), greaterThan(45));
  });

  testWidgets('привязка к нарисованному отрезку работает', (tester) async {
    final line = DrawnObject(
      id: 'l1',
      drawingId: 'd1',
      type: DrawnType.line,
      points: const [Offset(5, 5), Offset(7, 5)],
      createdAt: DateTime(2026, 10, 30),
    );
    final created = await pumpViewer(tester, objects: [line]);
    await selectTool(tester, 'point');
    // Точка чуть выше середины нарисованного отрезка — должна притянуться.
    await tester.tapAt(const Offset(400, 297));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    expect(created.first.type, DrawnType.point);
    expect(created.first.points.first.dx, closeTo(5, 0.4));
    expect(created.first.points.first.dy, closeTo(5, 0.05));
  });

  testWidgets('точка из «Точки»: удержание с лупой привязывается к линии',
      (tester) async {
    final line = DrawnObject(
      id: 'l1',
      drawingId: 'd1',
      type: DrawnType.line,
      points: const [Offset(5, 5), Offset(7, 5)],
      createdAt: DateTime(2026, 10, 30),
    );
    Offset? tapped;
    await pumpViewer(
      tester,
      mode: DrawingMode.annotation,
      objects: [line],
      onCanvasTap: (x, y) => tapped = Offset(x, y),
    );
    // Удержание чуть выше линии: точка должна притянуться к линии (dy ≈ 5).
    final g = await tester.startGesture(const Offset(400, 297));
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(tapped!.dy, closeTo(5, 0.05));
  });

  testWidgets('нарисованный текст: изменить содержимое и удалить объект',
      (tester) async {
    final updates = <DrawnObject>[];
    final deletes = <DrawnObject>[];
    final text = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(5, 5)],
      text: 'СТАРЫЙ',
      height: 14 / 54,
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(
      tester,
      mode: DrawingMode.overview,
      objects: [text],
      updates: updates,
      deletes: deletes,
    );

    // Тап по тексту — объект выбран, появляется панель действий.
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(find.text('Изменить'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);

    // Меняем текст.
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-text-field')), 'НОВЫЙ');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(updates, isNotEmpty);
    expect(updates.last.text, 'НОВЫЙ');

    // Удаляем объект.
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(deletes, hasLength(1));
    expect(deletes.first.id, 't1');
  });

  testWidgets('прямая создаётся по двум точкам (без зависания)',
      (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'ray');
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();
    await tester.tapAt(const Offset(600, 300));
    await tester.pumpAndSettle();

    expect(created.length, 1);
    expect(created.first.type, DrawnType.ray);
    expect(created.first.points.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('прямоугольник: вторая точка скольжением, без панорамы',
      (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'rectangle');
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = viewer.transformationController!;
    final before = controller.value.clone();

    await tester.dragFrom(const Offset(400, 250), const Offset(150, 100));
    await tester.pumpAndSettle();

    // Панорама в режиме рисования отключена — чертёж не сдвинулся.
    expect(controller.value, equals(before));
    // Скольжение поставило вторую точку и завершило прямоугольник.
    expect(created.length, 1);
    expect(created.first.type, DrawnType.rectangle);
    expect(created.first.points.length, 4);
  });

  testWidgets('панорама одним пальцем в режиме рисования отключена',
      (tester) async {
    await pumpViewer(tester);
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = viewer.transformationController!;
    final before = controller.value.clone();
    await tester.dragFrom(const Offset(400, 250), const Offset(120, 60));
    await tester.pumpAndSettle();
    expect(controller.value, equals(before));
  });

  testWidgets('текст масштабируется щипком двумя пальцами', (tester) async {
    final updates = <DrawnObject>[];
    final text = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(5, 5)],
      text: 'А',
      height: 14 / 54,
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [text], updates: updates);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    final g1 = await tester.startGesture(const Offset(380, 300));
    final g2 = await tester.startGesture(const Offset(420, 300));
    await tester.pump();
    // Разводим пальцы вдвое (40 px → 80 px).
    await g1.moveTo(const Offset(360, 300));
    await g2.moveTo(const Offset(440, 300));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.height!, greaterThan(14 / 54 * 1.6));
  });

  testWidgets('текст масштабируется щипком без верхнего предела',
      (tester) async {
    final updates = <DrawnObject>[];
    final text = DrawnObject(
      id: 't1',
      drawingId: 'd1',
      type: DrawnType.text,
      points: const [Offset(5, 5)],
      text: 'А',
      height: 14 / 54,
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [text], updates: updates);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    final g1 = await tester.startGesture(const Offset(380, 300));
    final g2 = await tester.startGesture(const Offset(420, 300));
    await tester.pump();
    // Разводим пальцы в 20 раз (40 px → 800 px): раньше высота упиралась
    // в предел 200 px экрана (≈3.7 мировых единиц при этом масштабе).
    await g1.moveTo(const Offset(0, 300));
    await g2.moveTo(const Offset(800, 300));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.height!, greaterThan(4.0),
        reason: 'предела увеличения быть не должно');
  });

  testWidgets('прямоугольник перемещается одним пальцем', (tester) async {
    final updates = <DrawnObject>[];
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(4, 4),
        Offset(6, 4),
        Offset(6, 6),
        Offset(4, 6),
      ],
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [rect], updates: updates);
    // Тап по линии (полоса выбора) — выбор; протаскивание — перенос.
    await tester.tapAt(const Offset(346, 300));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(346, 300), const Offset(54, 0));
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.points.length, 4);
    expect(updates.last.points.first.dx, closeTo(5, 0.6));
    expect(updates.last.points.first.dy, closeTo(4, 0.6));
  });

  testWidgets('при рисовании объекты не выделяются и не двигаются',
      (tester) async {
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(4, 4),
        Offset(6, 4),
        Offset(6, 6),
        Offset(4, 6),
      ],
      createdAt: DateTime(2026, 10, 30),
    );
    final updates = <DrawnObject>[];
    final created = await pumpViewer(
      tester,
      objects: [rect],
      updates: updates,
    );
    // Тап в центре — постановка точки.
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(updates, isEmpty);
    expect(created.length, 1);
    expect(created.first.type, DrawnType.point);
    // Тап на вершину/линию — тоже рисование: прямоугольник не выделяется
    // и не перетаскивается.
    await tester.tapAt(const Offset(346, 300));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(346, 300), const Offset(54, 0));
    await tester.pumpAndSettle();
    expect(updates, isEmpty);
  });

  testWidgets('в «Обзоре» прямоугольник выделяется и перемещается',
      (tester) async {
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(4, 4),
        Offset(6, 4),
        Offset(6, 6),
        Offset(4, 6),
      ],
      createdAt: DateTime(2026, 10, 30),
    );
    final updates = <DrawnObject>[];
    await pumpViewer(
      tester,
      mode: DrawingMode.overview,
      objects: [rect],
      updates: updates,
    );
    await tester.tapAt(const Offset(346, 300));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(346, 300), const Offset(54, 0));
    await tester.pumpAndSettle();
    expect(updates, isNotEmpty);
  });

  testWidgets('прямоугольник поворачивается двумя пальцами', (tester) async {
    final updates = <DrawnObject>[];
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(4, 4),
        Offset(6, 4),
        Offset(6, 6),
        Offset(4, 6),
      ],
      createdAt: DateTime(2026, 10, 30),
    );
    await pumpViewer(tester,
        mode: DrawingMode.overview, objects: [rect], updates: updates);
    await tester.tapAt(const Offset(346, 300));
    await tester.pumpAndSettle();
    final g1 = await tester.startGesture(const Offset(380, 300));
    final g2 = await tester.startGesture(const Offset(420, 300));
    await tester.pump();
    await g1.moveTo(const Offset(400, 280));
    await g2.moveTo(const Offset(400, 320));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    // Угол (4,4) повернулся вокруг центра (5,5) — позиция изменилась.
    final moved = updates.last.points.first;
    expect((moved - const Offset(4, 4)).distance, greaterThan(0.5));
  });

  testWidgets('слои: скрытый слой рисунков — объекты не выбираются',
      (tester) async {
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(4, 4),
        Offset(6, 4),
        Offset(6, 6),
        Offset(4, 6),
      ],
      layer: 'Слой 2',
      createdAt: DateTime(2026, 10, 30),
    );
    final updates = <DrawnObject>[];
    await pumpViewer(
      tester,
      objects: [rect],
      updates: updates,
      hiddenDrawnLayers: const {'Слой 2'},
    );
    // Тап по линии скрытого прямоугольника — не выбирает его.
    await tester.tapAt(const Offset(346, 300));
    await tester.pumpAndSettle();
    expect(updates, isEmpty);
  });

  testWidgets('слои: активный слой применяется к новым объектам',
      (tester) async {
    final created = await pumpViewer(
      tester,
      activeDrawnLayer: 'Слой 2',
    );
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    expect(created.first.layer, 'Слой 2');
  });

  testWidgets('смена размера области (клавиатура) не сбрасывает масштаб',
      (tester) async {
    var height = 600.0;
    late StateSetter setOuter;
    final doc = emptyDoc();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SizedBox(
                width: 800,
                height: height,
                child: DxfViewer(
                  document: doc,
                  annotations: const [],
                  hiddenLayers: const {},
                  mode: DrawingMode.drawing,
                  units: 'm',
                  onCanvasTap: (_, __) {},
                  snapSettings: SnapSettings(),
                  drawingId: 'd1',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = viewer.transformationController!;
    controller.value = Matrix4.identity()
      ..translateByDouble(100.0, 50.0, 0, 1)
      ..scaleByDouble(30.0, 30.0, 1, 1);
    await tester.pump();
    final before = controller.value.clone();
    setOuter(() => height = 400);
    await tester.pumpAndSettle();
    expect(controller.value, equals(before));
  });

  testWidgets('орто: отрезок выравнивается по оси', (tester) async {
    final created = await pumpViewer(
      tester,
      snapSettings: SnapSettings(ortho: true),
    );
    await selectTool(tester, 'line');
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();
    await tester.tapAt(const Offset(600, 300));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    final pts = created.first.points;
    expect(pts.length, 2);
    // |dx| > |dy| → горизонталь: Y обеих точек совпадает.
    expect(pts[1].dy, closeTo(pts[0].dy, 1e-6));
  });

  testWidgets('угловая привязка: угол кратен шагу 45°', (tester) async {
    final created = await pumpViewer(
      tester,
      snapSettings: SnapSettings(polarStep: 45),
    );
    await selectTool(tester, 'line');
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();
    await tester.tapAt(const Offset(600, 260));
    await tester.pumpAndSettle();
    expect(created.length, 1);
    final pts = created.first.points;
    final angDeg = math.atan2(pts[1].dy - pts[0].dy, pts[1].dx - pts[0].dx) *
        180 /
        math.pi;
    final rem = ((angDeg % 45) + 45) % 45;
    expect(rem < 0.1 || rem > 44.9, isTrue);
  });

  testWidgets('инструменты перетаскиваются в своём порядке', (tester) async {
    await pumpViewer(tester);
    // Порядок по умолчанию: точка, полилиния, отрезок…
    var pointX = tester.getCenter(find.byKey(const Key('draw-tool-point'))).dx;
    var polylineX =
        tester.getCenter(find.byKey(const Key('draw-tool-polyline'))).dx;
    expect(pointX, lessThan(polylineX));

    // Перетаскивание (жест обрабатывает ReorderableListView): двигаем «Точку»
    // после «Полилинии» через onReorder.
    final list = tester.widget<ReorderableListView>(
      find.byKey(const Key('draw-tools')),
    );
    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    pointX = tester.getCenter(find.byKey(const Key('draw-tool-point'))).dx;
    polylineX =
        tester.getCenter(find.byKey(const Key('draw-tool-polyline'))).dx;
    expect(pointX, greaterThan(polylineX));
  });

  Offset toScreen(WidgetTester tester, Offset world) {
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final doc = emptyDoc();
    final local = Offset(world.dx - doc.minX, doc.maxY - world.dy);
    return MatrixUtils.transformPoint(
        viewer.transformationController!.value, local);
  }

  testWidgets('точка: тап в режиме «Точка» привязывается к узлу',
      (tester) async {
    Offset? tapped;
    final created = await pumpViewer(
      tester,
      mode: DrawingMode.annotation,
      objects: [
        DrawnObject(
          id: 'l1',
          drawingId: 'd1',
          type: DrawnType.line,
          points: const [Offset(2, 2), Offset(8, 8)],
          createdAt: DateTime(2026),
        ),
      ],
      onCanvasTap: (x, y) => tapped = Offset(x, y),
    );
    await tester.tapAt(toScreen(tester, const Offset(2.1, 2.1)));
    await tester.pumpAndSettle();
    expect(created, isEmpty);
    expect(tapped, isNotNull);
    expect(tapped!.dx, closeTo(2, 0.05));
    expect(tapped!.dy, closeTo(2, 0.05));
  });

  testWidgets('точка: тап по существующей точке — выбор точки', (tester) async {
    List<Annotation>? cluster;
    final anns = [
      Annotation(
        id: 'a1',
        drawingId: 'd1',
        number: 1,
        dxfX: 5,
        dxfY: 5,
        createdAt: DateTime(2026),
      ),
      Annotation(
        id: 'a2',
        drawingId: 'd1',
        number: 2,
        dxfX: 5,
        dxfY: 5,
        createdAt: DateTime(2026),
      ),
    ];
    await pumpViewer(
      tester,
      mode: DrawingMode.annotation,
      annotations: anns,
      onClusterTap: (list, _) => cluster = list,
    );
    // Две точки в одной координате — тап открывает выбор точки.
    await tester.tapAt(toScreen(tester, const Offset(5, 5)));
    await tester.pumpAndSettle();
    expect(cluster, isNotNull);
    expect(cluster!.map((a) => a.number), [1, 2]);
  });

  testWidgets('несколько точек в одном месте — выбор точки', (tester) async {
    List<Annotation>? cluster;
    final anns = [
      Annotation(
          id: 'a1',
          drawingId: 'd1',
          number: 1,
          dxfX: 5,
          dxfY: 5,
          createdAt: DateTime(2026)),
      Annotation(
          id: 'a2',
          drawingId: 'd1',
          number: 2,
          dxfX: 5,
          dxfY: 5,
          createdAt: DateTime(2026)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: emptyDoc(),
              annotations: anns,
              hiddenLayers: const {},
              mode: DrawingMode.annotation,
              units: 'm',
              onCanvasTap: (_, __) {},
              snapSettings: SnapSettings(),
              drawingId: 'd1',
              drawnObjects: const [],
              onDrawnObjectCreated: (_) {},
              onAnnotationClusterTap: (list, __) => cluster = list,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(toScreen(tester, const Offset(5, 5)));
    await tester.pumpAndSettle();
    expect(cluster, isNotNull);
    expect(cluster!.map((a) => a.number), [1, 2]);
  });

  testWidgets('облако следует за пальцем без привязок', (tester) async {
    final created = await pumpViewer(
      tester,
      objects: [
        DrawnObject(
          id: 'l1',
          drawingId: 'd1',
          type: DrawnType.line,
          points: const [Offset(4, 4), Offset(6, 6)],
          createdAt: DateTime(2026),
        ),
      ],
    );
    await selectTool(tester, 'cloud');
    final gesture = await tester.startGesture(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(18, 12));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(created, hasLength(1));
    expect(created.first.points.length, greaterThan(3));
  });

  testWidgets('точка: протягивание пальца с привязкой к узлу', (tester) async {
    Offset? tapped;
    await pumpViewer(
      tester,
      mode: DrawingMode.annotation,
      objects: [
        DrawnObject(
          id: 'l1',
          drawingId: 'd1',
          type: DrawnType.line,
          points: const [Offset(2, 2), Offset(8, 8)],
          createdAt: DateTime(2026),
        ),
      ],
      onCanvasTap: (x, y) => tapped = Offset(x, y),
    );
    final g =
        await tester.startGesture(toScreen(tester, const Offset(2.1, 2.1)));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 120));
    await g.up();
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(tapped!.dx, closeTo(2, 0.1));
    expect(tapped!.dy, closeTo(2, 0.1));
  });

  testWidgets('отпускание второго пальца не завершает рисование',
      (tester) async {
    final created = await pumpViewer(tester);
    await selectTool(tester, 'cloud');
    // Рисуем первым пальцем (облако начинается сразу от пальца).
    final g1 = await tester.startGesture(const Offset(300, 1300));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await g1.moveBy(const Offset(30, 10));
      await tester.pump(const Duration(milliseconds: 40));
    }
    // Второй палец — масштабирование, затем отпускаем именно его.
    final g2 = await tester.startGesture(const Offset(600, 1200));
    await tester.pump(const Duration(milliseconds: 50));
    await g2.moveBy(const Offset(60, 60));
    await tester.pump(const Duration(milliseconds: 50));
    await g2.up();
    await tester.pump(const Duration(milliseconds: 100));
    // Второй палец отпущен — рисование продолжается (фигура не создана).
    expect(created, isEmpty);
    await g1.up();
    await tester.pumpAndSettle();
  });
}
