import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/utils/aci_colors.dart';
import 'package:menzulka/utils/layer_cache.dart';

void main() {
  Future<int> countPainted(DxfLayerCacheManager manager, double scale) async {
    final cache = manager.getLayerCache('0')!;
    final picture = cache.getPicture(scale: scale);
    final image = await picture.toImage(100, 100);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    var painted = 0;
    for (var i = 3; i < data!.lengthInBytes; i += 4) {
      if (data.getUint8(i) > 0) painted++;
    }
    image.dispose();
    return painted;
  }

  test('ACI palette has 256 entries and known base colors', () {
    expect(kAciDefaultColors.length, 256);
    expect(aciToColor(1).toARGB32(), 0xFFFF0000); // red
    expect(aciToColor(2).toARGB32(), 0xFFFFFF00); // yellow
    expect(aciToColor(7).toARGB32(), 0xFFFFFFFF); // white
  });

  test('LayerCache rasterizes geometry inside local canvas bounds', () async {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0', colorIndex: 7)],
      entities: [
        DxfLine(layer: '0', x1: 500000, y1: 500000, x2: 500100, y2: 500100),
      ],
      minX: 500000,
      minY: 500000,
      maxX: 500100,
      maxY: 500100,
    );
    final manager = DxfLayerCacheManager()..initialize(doc);
    final painted = await countPainted(manager, 1.0);
    expect(painted, greaterThan(0),
        reason: 'геометрия должна попасть в пределы локальной канвы 0..100');
  });

  test('LayerCache keeps lines visible when zoomed out', () async {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0', colorIndex: 7)],
      entities: [DxfLine(layer: '0', x1: 0, y1: 50, x2: 100, y2: 50)],
      minX: 0,
      minY: 0,
      maxX: 100,
      maxY: 100,
    );
    final manager = DxfLayerCacheManager()..initialize(doc);
    final atScale1 = await countPainted(manager, 1.0);
    final atScale01 = await countPainted(manager, 0.1);

    expect(atScale1, greaterThan(0));
    expect(atScale01, greaterThan(atScale1 * 3));
  });

  test('bulge polyline renders as an arc (cloud/rounded polyline)', () async {
    // Сегмент-полуокружность: положительный bulge даёт дугу над хордой.
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0', colorIndex: 7)],
      entities: [
        DxfLwPolyline(
          layer: '0',
          vertices: const [
            DxfVertex(10, 50, 1.0),
            DxfVertex(90, 50),
          ],
        ),
      ],
      minX: 0,
      minY: 0,
      maxX: 100,
      maxY: 100,
    );
    final manager = DxfLayerCacheManager()..initialize(doc);
    final picture = manager.getLayerCache('0')!.getPicture(scale: 1.0);
    final image = await picture.toImage(100, 100);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    // Положительный bulge = дуга против часовой стрелки в мировых координатах.
    // Для хорды слева-направо это нижняя полуокружность: в локальных
    // координатах (Y инвертирован) она уходит вниз, к y ≈ 90.
    bool paintedAt(int x, int y) {
      final offset = (y * 100 + x) * 4 + 3;
      return data!.getUint8(offset) > 0;
    }

    expect(paintedAt(50, 90), isTrue);
    expect(paintedAt(50, 10), isFalse);
    image.dispose();
  });
}
