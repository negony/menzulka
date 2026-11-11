import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/screens/drawing_screen.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/widgets/dxf_viewer.dart';
import 'package:menzulka/widgets/snap_loupe.dart';

void main() {
  testWidgets(
      'удержание показывает лупу, движение двигает привязку, '
      'отпускание ставит точку', (tester) async {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0')],
      entities: [
        DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
      ],
      minX: 0,
      minY: 0,
      maxX: 10,
      maxY: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: doc,
              annotations: const [],
              hiddenLayers: const {},
              mode: DrawingMode.measurement,
              units: 'm',
              onCanvasTap: (_, __) {},
              snapSettings: SnapSettings(),
              drawingId: 'd1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Экранная позиция локальной точки (5,5) — на линии.
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final matrix = viewer.transformationController!.value;
    final p = matrix.transform3(Vector3(5, 5, 0));

    final gesture = await tester.startGesture(Offset(p.x, p.y));
    // Удержание дольше long-press таймаута — должна появиться лупа.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SnapLoupe), findsOneWidget);

    // Смещение пальца без отрыва — привязка продолжает работать.
    await gesture.moveBy(const Offset(14, 0));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(SnapLoupe), findsOneWidget);

    // Отпускание — точка фиксируется, лупа скрывается, панель появилась.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SnapLoupe), findsNothing);
    expect(find.text('Контур открыт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('два дополнительных пальца масштабируют вокруг удержания',
      (tester) async {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0')],
      entities: [
        DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
      ],
      minX: 0,
      minY: 0,
      maxX: 10,
      maxY: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: doc,
              annotations: const [],
              hiddenLayers: const {},
              mode: DrawingMode.measurement,
              units: 'm',
              onCanvasTap: (_, __) {},
              snapSettings: SnapSettings(),
              drawingId: 'd1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = viewer.transformationController!;
    final before = controller.value.getMaxScaleOnAxis();
    final p = controller.value.transform3(Vector3(5, 5, 0));

    // Палец A — удержание (лупа).
    final aim = await tester.startGesture(Offset(p.x, p.y));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SnapLoupe), findsOneWidget);

    // Пальцы B и C — щипок вокруг точки удержания.
    final b = await tester.startGesture(Offset(p.x + 70, p.y + 70));
    final c = await tester.startGesture(Offset(p.x - 70, p.y - 70));
    await tester.pump();
    await b.moveBy(const Offset(40, 40));
    await c.moveBy(const Offset(-40, -40));
    await tester.pump();

    final after = controller.value.getMaxScaleOnAxis();
    expect(after, greaterThan(before * 1.05));
    expect(find.byType(SnapLoupe), findsOneWidget);

    await b.up();
    await c.up();
    await aim.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('панель измерений появляется сразу при входе в режим «Измерить»',
      (tester) async {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0')],
      entities: [
        DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
      ],
      minX: 0,
      minY: 0,
      maxX: 10,
      maxY: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: doc,
              annotations: const [],
              hiddenLayers: const {},
              mode: DrawingMode.measurement,
              units: 'm',
              onCanvasTap: (_, __) {},
              snapSettings: SnapSettings(),
              drawingId: 'd1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Панель видна сразу, без единой точки: подсказка и кнопки доступны.
    expect(find.text('Коснитесь чертежа'), findsOneWidget);
    expect(find.text('Контур открыт'), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);
    expect(find.text('Завершить'), findsOneWidget);
    expect(find.byType(SnapLoupe), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
