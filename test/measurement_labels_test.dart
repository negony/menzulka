import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/screens/drawing_screen.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/widgets/dxf_viewer.dart';
import 'package:menzulka/widgets/measurement_labels_painter.dart';

void main() {
  DxfDocument doc() => DxfDocument(
        layers: [DxfLayer(name: '0')],
        entities: [
          DxfLine(layer: '0', x1: 0, y1: 0, x2: 100, y2: 0),
        ],
        minX: 0,
        minY: 0,
        maxX: 100,
        maxY: 100,
      );

  Future<void> pumpViewer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DxfViewer(
              document: doc(),
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
  }

  Finder labelsFinder() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is MeasurementLabelsPainter,
      );

  testWidgets('подписи длин рисуются в экранном слое', (tester) async {
    await pumpViewer(tester);
    // Две точки — подпись стороны появляется в экранном слое.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.tapAt(const Offset(500, 300));
    await tester.pump();

    expect(labelsFinder(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('подписи следуют за зумом без масштабирования шрифта',
      (tester) async {
    await pumpViewer(tester);
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.tapAt(const Offset(500, 300));
    await tester.pump();

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = viewer.transformationController!;
    final before = controller.value.getMaxScaleOnAxis();

    // Сильный зум — подписи остаются в экранном слое и получают новую матрицу.
    controller.value = controller.value.clone()
      ..translateByDouble(400.0, 300.0, 0, 1)
      ..scaleByDouble(12.0, 12.0, 1, 1)
      ..translateByDouble(-400.0, -300.0, 0, 1);
    await tester.pump();

    expect(labelsFinder(), findsOneWidget);
    final labels = tester.widget<CustomPaint>(labelsFinder()).painter
        as MeasurementLabelsPainter;
    expect(labels.matrix.getMaxScaleOnAxis(), greaterThan(before * 5));
    expect(tester.takeException(), isNull);
  });
}
