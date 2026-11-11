// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:menzulka/services/dxf_parser.dart';
import 'package:menzulka/utils/dxf_overlays.dart';
import 'package:menzulka/widgets/dxf_overlay_painter.dart';

/// Проверяем, что подписи отрисовываются при разных масштабах (зум).
void main() {
  const path = r'D:\Documents\ХАЛТУРА\с рабочего стола\Jobs\M_TOPOS_POIMA.DXF';

  test('diagnose M_TOPOS labels at zoom', () async {
    if (!File(path).existsSync()) {
      print('файл отсутствует — пропуск');
      return;
    }
    final doc = await DxfParser().parseBytes(File(path).readAsBytesSync());
    final overlays = buildDxfOverlays(doc);
    print('labels=${overlays.texts.length}, points=${overlays.points.length}');
    if (overlays.texts.isEmpty) return;
    final first = overlays.texts.first;
    final lx = first.x - doc.minX;
    final ly = doc.maxY - first.y;
    print(
        'first label local=(${lx.toStringAsFixed(1)},${ly.toStringAsFixed(1)}) '
        'height=${first.height}');

    for (final s in [3.8, 20.0, 200.0, 2000.0]) {
      final m = Matrix4.identity()
        ..translateByDouble(256 - s * lx, 256 - s * ly, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      DxfTextPainter(
        overlays: overlays,
        matrix: m,
        minX: doc.minX,
        maxY: doc.maxY,
      ).paint(canvas, const ui.Size(512, 512));
      final image = await rec.endRecording().toImage(512, 512);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      var painted = 0;
      for (var i = 3; i < data!.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 0) painted++;
      }
      print('zoomScale=$s -> labelPaintedPixels=$painted');
      image.dispose();
    }
  });
}
