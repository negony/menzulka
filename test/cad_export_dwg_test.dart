import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/services/cad_conversion_exception.dart';
import 'package:menzulka/services/cad_converter.dart';
import 'package:menzulka/services/cad_export_version.dart';

/// Минимальный DXF в стиле AutoCAD (пары код/значение).
String _dxf() {
  String c(int code, String value) => '${code.toString().padLeft(3)}\n$value\n';
  final b = StringBuffer();
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'HEADER'));
  b.write(c(9, r'$ACADVER'));
  b.write(c(1, 'AC1027'));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'TABLES'));
  b.write(c(0, 'TABLE'));
  b.write(c(2, 'LAYER'));
  b.write(c(70, '1'));
  b.write(c(0, 'LAYER'));
  b.write(c(2, '0'));
  b.write(c(70, '0'));
  b.write(c(62, '7'));
  b.write(c(6, 'CONTINUOUS'));
  b.write(c(0, 'ENDTAB'));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'SECTION'));
  b.write(c(2, 'ENTITIES'));
  b.write(c(0, 'LINE'));
  b.write(c(8, '0'));
  b.write(c(10, '0'));
  b.write(c(20, '0'));
  b.write(c(11, '10'));
  b.write(c(21, '5'));
  b.write(c(0, 'ENDSEC'));
  b.write(c(0, 'EOF'));
  return b.toString();
}

void main() {
  group('DwgExportVersion', () {
    test('коды и подписи версий', () {
      expect(DwgExportVersion.r2018.code, 'AC1032');
      expect(DwgExportVersion.r2013.code, 'AC1027');
      expect(DwgExportVersion.r2007.code, 'AC1021');
      expect(DwgExportVersion.r2018.flagBits, 0);
      expect(DwgExportVersion.r2013.flagBits, 1);
      expect(DwgExportVersion.r2007.flagBits, 2);
      expect(DwgExportVersion.r2018.dialogLabel, 'DWG 2018');
    });
  });

  test('DXF → DWG: три версии, корректный заголовок файла', () {
    if (!CadConverter.isAvailable) {
      // ignore: avoid_print
      print('пропуск: нативная библиотека не собрана');
      return;
    }
    final workDir =
        Directory.systemTemp.createTempSync('menzulka_export_dwg').path;
    final dxf = Uint8List.fromList(_dxf().codeUnits);
    for (final version in DwgExportVersion.values) {
      final dwg =
          CadConverter.dxfToDwgSync(dxf, workDir: workDir, version: version);
      expect(dwg.length, greaterThan(200),
          reason: 'DWG ${version.label}: слишком маленький файл');
      expect(String.fromCharCodes(dwg.sublist(0, 6)), version.code,
          reason: 'DWG ${version.label}: неверный заголовок');
    }
  });

  test('мусор вместо DXF даёт понятную ошибку', () {
    if (!CadConverter.isAvailable) return;
    final workDir =
        Directory.systemTemp.createTempSync('menzulka_export_dwg').path;
    expect(
      () => CadConverter.dxfToDwgSync(
        Uint8List.fromList('не чертёж'.codeUnits),
        workDir: workDir,
      ),
      throwsA(isA<CadConversionException>()),
    );
  });

  test('модуль сообщает новую версию', () {
    if (!CadConverter.isAvailable) return;
    final version = CadConverter.nativeVersion;
    expect(version, isNotNull);
    expect(version, contains('menzulka_cad'));
  });
}
