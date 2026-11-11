import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/drawn_object.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/screens/drawing_screen.dart';
import 'package:menzulka/widgets/dxf_viewer.dart';

void main() {
  DxfDocument doc({List<DxfEntity> entities = const []}) => DxfDocument(
        layers: [DxfLayer(name: '0')],
        entities: entities,
        minX: 0,
        minY: 0,
        maxX: 10,
        maxY: 10,
      );

  Future<List<DrawnObject>> pump(
    WidgetTester tester, {
    DrawingMode mode = DrawingMode.drawing,
    List<DrawnObject> objects = const [],
    List<DrawnObject>? updates,
    List<DxfEntity> entities = const [],
  }) async {
    final created = <DrawnObject>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: DxfViewer(
            document: doc(entities: entities),
            annotations: const [],
            hiddenLayers: const {},
            mode: mode,
            units: 'm',
            onCanvasTap: (_, __) {},
            snapSettings: SnapSettings(),
            drawingId: 'd1',
            drawnObjects: objects,
            onDrawnObjectCreated: created.add,
            onDrawnObjectUpdated: updates?.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return created;
  }

  Future<void> selectTool(WidgetTester tester, String name) async {
    final finder = find.byKey(Key('draw-tool-$name'));
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

  testWidgets('правая кнопка мыши завершает полилинию', (tester) async {
    final created = await pump(tester);
    await selectTool(tester, 'polyline');

    await tester.tapAt(const Offset(300, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(500, 300));
    await tester.pumpAndSettle();
    expect(created, isEmpty, reason: 'без завершения объект не создаётся');

    final click = await tester.startGesture(
      const Offset(400, 200),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await click.up();
    await tester.pumpAndSettle();

    expect(created.length, 1);
    expect(created.first.type, DrawnType.polyline);
    expect(created.first.points.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('средняя кнопка мыши панорамирует и не рисует', (tester) async {
    final created = await pump(tester);
    await selectTool(tester, 'point');

    Matrix4 matrix() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    final before = matrix().clone();

    final pan = await tester.startGesture(
      const Offset(400, 300),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await tester.pump();
    await pan.moveBy(const Offset(60, 40));
    await tester.pump();
    await pan.up();
    await tester.pumpAndSettle();

    final after = matrix();
    expect(after.getTranslation().x, isNot(before.getTranslation().x));
    expect(after.getTranslation().y, isNot(before.getTranslation().y));
    expect(created, isEmpty, reason: 'средняя кнопка не должна рисовать');
    expect(tester.takeException(), isNull);
  });

  testWidgets('текст: уголок-ручка поворота поворачивает текст',
      (tester) async {
    final updates = <DrawnObject>[];
    await pump(
      tester,
      mode: DrawingMode.overview,
      objects: [
        DrawnObject(
          id: 'obj1',
          drawingId: 'd1',
          type: DrawnType.text,
          points: const [Offset(5, 5)],
          text: 'ABC',
          height: 1.0,
          color: 0xFFFF0000,
          strokePx: 1.2,
          layer: kDefaultDrawnLayer,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      updates: updates,
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('text-rotate-handle')), findsOneWidget);

    final handle =
        tester.getCenter(find.byKey(const Key('text-rotate-handle')));
    final drag = await tester.startGesture(handle);
    await tester.pump();
    await drag.moveBy(const Offset(40, 70));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.rotation.abs(), greaterThan(1.0),
        reason: 'поворот должен измениться');
  });

  testWidgets('координаты: H берётся из объекта чертежа', (tester) async {
    await pump(
      tester,
      mode: DrawingMode.coordinates,
      entities: [
        DxfLine(
          layer: '0',
          elevation: 2.5,
          x1: 0,
          y1: 5,
          x2: 10,
          y2: 5,
        ),
      ],
    );

    // Точка на линии (мировые (5,5) -> экран (400,300)).
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    expect(find.text('H'), findsOneWidget);
    expect(find.textContaining('2.500'), findsOneWidget,
        reason: 'H = отметка линии 2.5');
  });
}
