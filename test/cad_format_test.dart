import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/services/cad_format.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

Uint8List _dwgHeader(String code, {int padding = 64}) {
  final builder = BytesBuilder();
  builder.add(ascii.encode(code));
  builder.add(Uint8List(padding));
  return builder.toBytes();
}

void main() {
  group('CadFormatDetector.dwgVersion', () {
    for (final code in [
      'AC1009',
      'AC1012',
      'AC1014',
      'AC1015',
      'AC1018',
      'AC1021',
      'AC1024',
      'AC1027',
      'AC1032',
    ]) {
      test('распознаёт $code', () {
        expect(CadFormatDetector.dwgVersion(_dwgHeader(code)), code);
        expect(CadFormatDetector.isDwg(_dwgHeader(code)), isTrue);
      });
    }

    test('не считает DWG короткий файл и мусор', () {
      expect(
          CadFormatDetector.dwgVersion(Uint8List.fromList([1, 2, 3])), isNull);
      expect(CadFormatDetector.dwgVersion(_bytes('HELLO WORLD')), isNull);
      expect(CadFormatDetector.isDwg(_bytes('AC10')), isFalse);
    });

    test('новая версия DWG распознаётся, но помечается как неподдерживаемая',
        () {
      final future = _dwgHeader('AC1033');
      expect(CadFormatDetector.dwgVersion(future), 'AC1033');
      expect(CadFormatDetector.isKnownDwgVersion(future), isFalse);
      expect(CadFormatDetector.isKnownDwgVersion(_dwgHeader('AC1032')), isTrue);
    });
  });

  group('CadFormatDetector.detect', () {
    test('DWG', () {
      expect(
        CadFormatDetector.detect(_dwgHeader('AC1027')),
        CadFormat.dwg,
      );
    });

    test('бинарный DXF', () {
      final bytes = _bytes('AutoCAD Binary DXF\r\n\x1a\x00');
      expect(CadFormatDetector.isBinaryDxf(bytes), isTrue);
      expect(CadFormatDetector.detect(bytes), CadFormat.binaryDxf);
    });

    test('текстовый DXF', () {
      const dxf = '0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n';
      expect(CadFormatDetector.detect(_bytes(dxf)), CadFormat.dxf);
    });

    test('пустой файл и мусор — unknown', () {
      expect(CadFormatDetector.detect(Uint8List(0)), CadFormat.unknown);
      expect(CadFormatDetector.detect(_bytes('не чертёж')), CadFormat.unknown);
    });
  });
}
