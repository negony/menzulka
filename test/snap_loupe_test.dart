import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/models/snap_models.dart';
import 'package:menzulka/utils/layer_cache.dart';
import 'package:menzulka/widgets/snap_loupe.dart';

void main() {
  testWidgets('SnapLoupe рисует увеличение без ошибок', (tester) async {
    final document = DxfDocument(
      layers: const [],
      entities: [
        DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 10),
        DxfCircle(layer: '0', cx: 5, cy: 5, radius: 4),
      ],
      blocks: const {},
      minX: 0,
      minY: 0,
      maxX: 10,
      maxY: 10,
    );
    final cache = DxfLayerCacheManager()..initialize(document);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SnapLoupe(
              cacheManager: cache,
              hiddenLayers: const {},
              aimLocal: const Offset(5, 5),
              snap: const SnapResult(
                point: Offset(5, 5),
                type: SnapType.vertex,
                distance: 0.2,
              ),
              mainScale: 4,
              measurementPoints: const [Offset(1, 1), Offset(3, 3)],
              closed: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SnapLoupe), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    cache.dispose();
  });
}
