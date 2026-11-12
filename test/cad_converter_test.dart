import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/services/cad_conversion_exception.dart';
import 'package:menzulka/services/cad_converter.dart';
import 'package:menzulka/services/cad_format.dart';
import 'package:menzulka/services/dxf_parser.dart';

/// Интеграционные тесты нативного слоя DWG → DXF.
///
/// Требуют собранной библиотеки (`tool/build_native.ps1`) и DWG-фикстуры
/// (`native/examples/make_fixture.rs`). В CI без нативной сборки тесты
/// помечаются как пропущенные, поэтому `flutter test` остаётся зелёным.
void main() {
  final fixture = File('test/fixtures/sample_r2018.dwg');
  final canRun = CadConverter.isAvailable && fixture.existsSync();

  test('нативная библиотека: версия читается', () {
    if (!CadConverter.isAvailable) {
      // ignore: avoid_print
      print('пропуск: нативная библиотека не собрана');
      return;
    }
    final version = CadConverter.nativeVersion;
    expect(version, isNotNull);
    expect(version, contains('menzulka_cad'));
    // ignore: avoid_print
    print('native: $version');
  });

  test('DWG R2018 конвертируется в DXF и разбирается парсером', () async {
    if (!canRun) {
      // ignore: avoid_print
      print('пропуск: нет нативной библиотеки или фикстуры');
      return;
    }
    final dwg = await fixture.readAsBytes();
    expect(CadFormatDetector.detect(dwg), CadFormat.dwg);
    expect(CadFormatDetector.isKnownDwgVersion(dwg), isTrue);

    final dxf = CadConverter.dwgToDxfSync(dwg,
        workDir: Directory.systemTemp.createTempSync('menzulka_cad_test').path);
    expect(dxf, isNotEmpty);
    expect(CadFormatDetector.detect(dxf), CadFormat.dxf);

    final document = await DxfParser().parseBytes(dxf);
    expect(document.entities, isNotEmpty,
        reason: 'после конвертации в DXF должны быть примитивы');
    expect(document.layers, isNotEmpty);
  });

  test('неподдерживаемая версия DWG даёт код 2', () {
    if (!CadConverter.isAvailable) {
      return;
    }
    final future = BytesBuilder()
      ..add('AC1033'.codeUnits)
      ..add(Uint8List(64));
    expect(
      () => CadConverter.dwgToDxfSync(
        future.toBytes(),
        workDir: Directory.systemTemp.createTempSync('menzulka_cad_test').path,
      ),
      throwsA(isA<CadConversionException>().having((e) => e.code, 'code', 2)),
    );
  });

  test('мусор вместо DWG даёт понятную ошибку', () {
    if (!CadConverter.isAvailable) {
      return;
    }
    expect(
      () => CadConverter.dwgToDxfSync(
        Uint8List.fromList('AC1027'.codeUnits),
        workDir: Directory.systemTemp.createTempSync('menzulka_cad_test').path,
      ),
      throwsA(isA<CadConversionException>()),
    );
  });
}
