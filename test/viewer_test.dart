import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/screens/drawing_screen.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/widgets/dxf_viewer.dart';

void main() {
  testWidgets('DxfViewer fits a large-coordinate drawing into the viewport',
      (WidgetTester tester) async {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0')],
      entities: [
        DxfLine(layer: '0', x1: 500000, y1: 500000, x2: 500100, y2: 500100),
        DxfLine(layer: '0', x1: 500100, y1: 500000, x2: 500000, y2: 500100),
      ],
      minX: 500000,
      minY: 500000,
      maxX: 500100,
      maxY: 500100,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DxfViewer(
            document: doc,
            annotations: const [],
            hiddenLayers: const {},
            mode: DrawingMode.overview,
            units: 'm',
            onCanvasTap: (_, __) {},
            snapSettings: SnapSettings(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final matrix = viewer.transformationController!.value;
    final size = tester.getSize(find.byType(DxfViewer));

    // Локальные углы чертежа (0,0) и (boxW, boxH) после вписывания
    // должны оказаться внутри видимой области.
    final p0 = matrix.transform3(Vector3(0, 0, 0));
    final p1 = matrix.transform3(Vector3(100, 100, 0));

    expect(p0.x, inInclusiveRange(0, size.width));
    expect(p0.y, inInclusiveRange(0, size.height));
    expect(p1.x, inInclusiveRange(0, size.width));
    expect(p1.y, inInclusiveRange(0, size.height));

    // И чертеж должен занимать заметную часть экрана, а не быть точкой.
    expect((p1.x - p0.x).abs(), greaterThan(size.width * 0.5));
    expect((p1.y - p0.y).abs(), greaterThan(size.height * 0.5));
  });
}
