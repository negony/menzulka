import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/models/dxf_models.dart';
import 'package:menzulka/services/dxf_parser.dart';

void main() {
  test('DxfParser parses POINT entities and includes them in extents',
      () async {
    final dxf = StringBuffer()
      ..write('0\nSECTION\n2\nENTITIES\n')
      ..write('0\nPOINT\n8\n0\n10\n100.0\n20\n200.0\n')
      ..write('0\nPOINT\n8\n0\n10\n300.0\n20\n400.0\n')
      ..write('0\nENDSEC\n0\nEOF\n');

    final doc = await DxfParser()
        .parseBytes(Uint8List.fromList(utf8.encode(dxf.toString())));

    final points = doc.entities.whereType<DxfPoint>().toList();
    expect(points.length, 2);
    expect(points.first.x, 100.0);
    expect(points.first.y, 200.0);

    expect(doc.minX, 100.0);
    expect(doc.maxX, 300.0);
    expect(doc.minY, 200.0);
    expect(doc.maxY, 400.0);
  });

  test('пустой DXF (только ENTITIES) — пустой документ с границами 0..100',
      () async {
    const dxf = '0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n';

    final doc =
        await DxfParser().parseBytes(Uint8List.fromList(utf8.encode(dxf)));

    expect(doc.entities, isEmpty);
    expect(doc.minX, 0.0);
    expect(doc.minY, 0.0);
    expect(doc.maxX, 100.0);
    expect(doc.maxY, 100.0);
  });
}
