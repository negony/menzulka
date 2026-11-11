import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:menzulka/models/drawn_object.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/screens/drawing_screen.dart';
import 'package:menzulka/widgets/dxf_viewer.dart';

void main() {
  DxfDocument doc({Set<String> hiddenLayers = const {}}) => DxfDocument(
        layers: [DxfLayer(name: '0'), DxfLayer(name: 'HID')],
        entities: [
          DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
          DxfLine(layer: '0', x1: 0, y1: 10, x2: 10, y2: 0),
          DxfLine(layer: '0', x1: 2, y1: 8, x2: 8, y2: 2),
          DxfLine(layer: 'HID', x1: 1, y1: 1, x2: 3, y2: 1),
        ],
        minX: 0,
        minY: 0,
        maxX: 10,
        maxY: 10,
      );

  Future<void> pump(
    WidgetTester tester, {
    DrawingMode mode = DrawingMode.coordinates,
    SnapSettings? settings,
    List<DrawnObject> objects = const [],
    Set<String> hiddenLayers = const {},
    Set<String> hiddenDrawnLayers = const {},
    void Function(double dxfX, double dxfY)? onCreatePointAt,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: doc(),
              annotations: const [],
              hiddenLayers: hiddenLayers,
              mode: mode,
              units: 'm',
              onCanvasTap: (_, __) {},
              snapSettings: settings ?? SnapSettings(),
              onCreatePointAt: onCreatePointAt,
              drawnObjects: objects,
              hiddenDrawnLayers: hiddenDrawnLayers,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Экранная позиция мировой точки (документ 0..10 × 0..10).
  Offset toScreen(WidgetTester tester, Offset world) {
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final m = viewer.transformationController!.value;
    final local = Offset(world.dx - 0, 10 - world.dy);
    final v = m.transform3(Vector3(local.dx, local.dy, 0));
    return Offset(v.x, v.y);
  }

  testWidgets('тап по узлу: координаты и тип привязки', (tester) async {
    await pump(tester);
    await tester.tapAt(toScreen(tester, const Offset(2, 8)));
    await tester.pumpAndSettle();
    expect(find.text('Конечная точка · чертёж'), findsOneWidget);
    expect(find.text('2.000 м'), findsOneWidget);
    expect(find.text('8.000 м'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('тап на пересечении двух линий', (tester) async {
    await pump(tester);
    await tester.tapAt(toScreen(tester, const Offset(5, 5)));
    await tester.pumpAndSettle();
    expect(find.text('Пересечение · чертёж'), findsOneWidget);
    expect(find.text('5.000 м'), findsNWidgets(2));
  });

  testWidgets('угол нарисованного прямоугольника — источник «рисунок»',
      (tester) async {
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(2, 2),
        Offset(6, 2),
        Offset(6, 6),
        Offset(2, 6),
      ],
      createdAt: DateTime(2026, 10, 30),
    );
    await pump(tester, objects: [rect]);
    await tester.tapAt(toScreen(tester, const Offset(2, 6)));
    await tester.pumpAndSettle();
    expect(find.text('Конечная точка · рисунок'), findsOneWidget);
    expect(find.text('2.000 м'), findsOneWidget);
    expect(find.text('6.000 м'), findsOneWidget);
  });

  testWidgets('скрытый слой рисунков — привязки нет', (tester) async {
    final rect = DrawnObject(
      id: 'r1',
      drawingId: 'd1',
      type: DrawnType.rectangle,
      points: const [
        Offset(2, 2),
        Offset(6, 2),
        Offset(6, 6),
        Offset(2, 6),
      ],
      createdAt: DateTime(2026, 10, 30),
    );
    await pump(
      tester,
      objects: [rect],
      hiddenDrawnLayers: const {kDefaultDrawnLayer},
    );
    await tester.tapAt(toScreen(tester, const Offset(2, 6)));
    await tester.pumpAndSettle();
    // Без привязки координаты всё равно показываются (пустое место).
    expect(find.text('Без привязки'), findsOneWidget);
  });

  testWidgets('скрытый слой DXF — привязки нет', (tester) async {
    await pump(tester, hiddenLayers: const {'0'});
    await tester.tapAt(toScreen(tester, const Offset(2, 8)));
    await tester.pumpAndSettle();
    expect(find.text('Без привязки'), findsOneWidget);
  });

  testWidgets('«+ Точка» отдаёт координаты в onCreatePointAt', (tester) async {
    final captured = <({double x, double y})>[];
    await pump(
      tester,
      onCreatePointAt: (x, y) => captured.add((x: x, y: y)),
    );
    await tester.tapAt(toScreen(tester, const Offset(2, 8)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coord-create-point')));
    await tester.pumpAndSettle();
    expect(captured.length, 1);
    expect(captured.first.x, closeTo(2, 1e-6));
    expect(captured.first.y, closeTo(8, 1e-6));
  });

  testWidgets('«Копировать X,Y» кладёт числа в буфер', (tester) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        log.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await pump(tester);
    await tester.tapAt(toScreen(tester, const Offset(2, 8)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coord-copy')));
    await tester.pumpAndSettle();
    final calls = log.where((c) => c.method == 'Clipboard.setData').toList();
    expect(calls, isNotEmpty);
    expect((calls.last.arguments as Map)['text'], '2.000 8.000');
    expect(find.text('Скопировано: 2.000 8.000'), findsOneWidget);
  });

  testWidgets('выключенные привязки — координаты без привязки', (tester) async {
    await pump(tester, settings: SnapSettings(enabled: false));
    await tester.tapAt(toScreen(tester, const Offset(2, 8)));
    await tester.pumpAndSettle();
    expect(find.text('Без привязки'), findsOneWidget);
    expect(find.text('2.000 м'), findsOneWidget);
    expect(find.text('8.000 м'), findsOneWidget);
  });

  testWidgets('протягивание пальцем обновляет показания', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(
      toScreen(tester, const Offset(2, 8)),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Конечная точка · чертёж'), findsOneWidget);
    await gesture.moveTo(toScreen(tester, const Offset(5, 5)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Пересечение · чертёж'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Пересечение · чертёж'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('два пальца меняют масштаб/панораму в режиме координат',
      (tester) async {
    await pump(tester);
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final before = viewer.transformationController!.value.clone();
    final g1 = await tester.startGesture(
      toScreen(tester, const Offset(4, 6)),
    );
    final g2 = await tester.startGesture(
      toScreen(tester, const Offset(6, 4)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await g1.moveTo(toScreen(tester, const Offset(3, 7)));
    await g2.moveTo(toScreen(tester, const Offset(7, 3)));
    await tester.pump(const Duration(milliseconds: 40));
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    final after = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    expect(after, isNot(before));
    expect(tester.takeException(), isNull);
  });
}
