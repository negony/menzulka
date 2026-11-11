import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/services/dxf_parser.dart';
import 'package:menzulka/utils/dxf_overlays.dart';
import 'package:menzulka/utils/layer_cache.dart';

Future<DxfDocument> _parse(String s) =>
    DxfParser().parseBytes(Uint8List.fromList(utf8.encode(s)));

DxfDocument _doc100(
  List<DxfEntity> entities, {
  Map<String, DxfBlock> blocks = const {},
}) {
  return DxfDocument(
    layers: [DxfLayer(name: '0'), DxfLayer(name: 'RED', colorIndex: 1)],
    entities: entities,
    blocks: blocks,
    minX: 0,
    minY: 0,
    maxX: 100,
    maxY: 100,
  );
}

Future<ByteData> _render(DxfDocument doc, {String layer = '0'}) async {
  final manager = DxfLayerCacheManager()..initialize(doc);
  final cache = manager.getLayerCache(layer);
  expect(cache, isNotNull, reason: 'слой $layer должен иметь кэш');
  final picture = cache!.getPicture(scale: 1.0);
  final image = await picture.toImage(100, 100);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!;
}

bool _painted(ByteData data, int x, int y) =>
    data.getUint8((y * 100 + x) * 4 + 3) > 0;

void main() {
  const header = '0\nSECTION\n2\nTABLES\n'
      '0\nLAYER\n2\nRED\n62\n1\n70\n0\n0\nENDSEC\n';
  const blocks = '0\nSECTION\n2\nBLOCKS\n'
      '0\nBLOCK\n2\nSYM\n70\n0\n10\n0\n20\n0\n'
      '0\nLINE\n8\n0\n10\n0\n20\n0\n11\n10\n21\n0\n'
      '0\nENDBLK\n0\nENDSEC\n';
  const entitiesHead = '0\nSECTION\n2\nENTITIES\n';

  test('parses ARC, ELLIPSE, INSERT and BLOCK definitions', () async {
    final doc = await _parse(
        '$header$blocks${entitiesHead}0\nARC\n8\n0\n10\n50\n20\n50\n40\n10\n50\n0\n51\n90\n0\nELLIPSE\n8\n0\n10\n50\n20\n50\n11\n20\n21\n0\n40\n0.5\n41\n0\n42\n6.283185307179586\n0\nINSERT\n8\n0\n2\nSYM\n10\n20\n20\n20\n0\nENDSEC\n0\nEOF\n');

    expect(doc.layers.any((l) => l.name == 'RED' && l.colorIndex == 1), isTrue);
    expect(doc.blocks.containsKey('SYM'), isTrue);
    expect(doc.blocks['SYM']!.entities.whereType<DxfLine>().length, 1);
    expect(doc.entities.whereType<DxfArc>().length, 1);
    expect(doc.entities.whereType<DxfEllipse>().length, 1);
    expect(doc.entities.whereType<DxfInsert>().length, 1);
  });

  test('INSERT extents include block geometry', () async {
    final doc = await _parse(
        '$header$blocks${entitiesHead}0\nINSERT\n8\n0\n2\nSYM\n10\n50\n20\n50\n0\nENDSEC\n0\nEOF\n');
    // Блок — линия (0,0)-(10,0); вставка в (50,50) -> 50..60 по X.
    expect(doc.minX, closeTo(50, 1e-6));
    expect(doc.maxX, closeTo(60, 1e-6));
  });

  test('entity gets its layer ACI color (BYLAYER)', () async {
    final doc = _doc100([
      DxfLine(layer: 'RED', x1: 10, y1: 50, x2: 90, y2: 50),
    ]);
    final data = await _render(doc, layer: 'RED');
    const idx = (50 * 100 + 50) * 4;
    // ACI 1 = красный (антиалиасинг может снизить насыщенность канала).
    expect(data.getUint8(idx + 3), greaterThan(100)); // есть заливка
    expect(data.getUint8(idx), greaterThan(150)); // R
    expect(data.getUint8(idx + 1), lessThan(50)); // G
    expect(data.getUint8(idx + 2), lessThan(50)); // B
  });

  test('INSERT expands block geometry at insert point', () async {
    final doc = _doc100(
      [DxfInsert(layer: '0', blockName: 'SYM', x: 50, y: 50)],
      blocks: {
        'SYM': DxfBlock(name: 'SYM', entities: [
          DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
        ]),
      },
    );
    final data = await _render(doc);
    // Линия (50,50)-(60,50) в мировых координатах.
    expect(_painted(data, 55, 50), isTrue);
  });

  test('INSERT rotation is applied counter-clockwise', () async {
    final doc = _doc100(
      [DxfInsert(layer: '0', blockName: 'SYM', x: 50, y: 50, rotation: 90)],
      blocks: {
        'SYM': DxfBlock(name: 'SYM', entities: [
          DxfLine(layer: '0', x1: 0, y1: 0, x2: 10, y2: 0),
        ]),
      },
    );
    final data = await _render(doc);
    // +90°: (10,0) -> (0,10) — линия идёт вверх по экрану (y < 50).
    expect(_painted(data, 50, 45), isTrue);
  });

  test('overlays collect points and texts, including block contents', () {
    final doc = DxfDocument(
      layers: [DxfLayer(name: '0'), DxfLayer(name: 'RED', colorIndex: 1)],
      entities: [
        DxfPoint(layer: 'RED', x: 10, y: 20),
        DxfText(layer: '0', x: 30, y: 40, content: 'A', height: 2.5),
        DxfInsert(layer: '0', blockName: 'SYM', x: 100, y: 100),
      ],
      blocks: {
        'SYM': DxfBlock(name: 'SYM', entities: [
          DxfPoint(layer: '0', x: 0, y: 0),
          DxfText(layer: '0', x: 5, y: 5, content: 'B', height: 2.0),
        ]),
      },
      minX: 0,
      minY: 0,
      maxX: 200,
      maxY: 200,
    );
    final ov = buildDxfOverlays(doc);
    expect(ov.points.length, 2);
    expect(ov.texts.length, 2);

    final red = ov.points.firstWhere((p) => (p.x - 10).abs() < 1e-6);
    expect(red.color.computeLuminance(), lessThan(0.5)); // ACI 1 — красный

    final inBlock = ov.points.firstWhere((p) => (p.x - 100).abs() < 1e-6);
    expect(inBlock.color.computeLuminance(), greaterThan(0.5)); // ACI 7 — белый
  });

  test('lineweight maps to increasing stroke thickness', () {
    expect(lineWeightToPx(0), greaterThan(0));
    expect(lineWeightToPx(25), lessThan(lineWeightToPx(50)));
    expect(lineWeightToPx(50), lessThan(lineWeightToPx(100)));
  });

  test('lineweight resolves BYLAYER from layer definition', () {
    final layers = {'0': DxfLayer(name: '0', lineWeight: 50)};
    final e = DxfLine(layer: '0', lineWeight: -1, x1: 0, y1: 0, x2: 1, y2: 1);
    expect(resolveDxfLineWeight(e, layers, null), 50);
  });
}
