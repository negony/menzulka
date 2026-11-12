/// Определение формата CAD-файла по содержимому (а не по расширению).
///
/// На Android имя файла, полученное из `file_selector`, часто не содержит
/// расширения, поэтому формат определяется по сигнатуре.
library;

import 'dart:convert';
import 'dart:typed_data';

enum CadFormat {
  /// Текстовый DXF (обычный случай).
  dxf,

  /// Бинарный DXF («AutoCAD Binary DXF» в начале файла).
  binaryDxf,

  /// Бинарный DWG (сигнатура AC10xx).
  dwg,

  /// Неизвестный формат.
  unknown,
}

class CadFormatDetector {
  const CadFormatDetector._();

  /// Известные коды версий DWG (R12 … R2018+), которые умеет нативный слой.
  static const List<String> knownDwgCodes = [
    'AC1009', // R11/R12
    'AC1012', // R13
    'AC1014', // R14
    'AC1015', // 2000
    'AC1018', // 2004
    'AC1021', // 2007
    'AC1024', // 2010
    'AC1027', // 2013
    'AC1032', // 2018+
  ];

  /// Код версии DWG из заголовка файла (`AC10xx`) или `null`.
  static String? dwgVersion(Uint8List bytes) {
    if (bytes.length < 6) return null;
    final String header;
    try {
      header = ascii.decode(bytes.sublist(0, 6));
    } on FormatException {
      return null;
    }
    if (header.length == 6 && header.startsWith('AC10')) {
      final code = int.tryParse(header.substring(2));
      if (code != null) return header;
    }
    return null;
  }

  static bool isDwg(Uint8List bytes) => dwgVersion(bytes) != null;

  /// Поддерживается ли версия нативным слоем (для подсказки пользователю).
  static bool isKnownDwgVersion(Uint8List bytes) {
    final version = dwgVersion(bytes);
    return version != null && knownDwgCodes.contains(version);
  }

  static bool isBinaryDxf(Uint8List bytes) {
    const marker = 'AutoCAD Binary DXF';
    if (bytes.length < marker.length) return false;
    try {
      return ascii.decode(bytes.sublist(0, marker.length)) == marker;
    } on FormatException {
      return false;
    }
  }

  static CadFormat detect(Uint8List bytes) {
    if (bytes.isEmpty) return CadFormat.unknown;
    if (isDwg(bytes)) return CadFormat.dwg;
    if (isBinaryDxf(bytes)) return CadFormat.binaryDxf;
    // Текстовый DXF начинается с пары (код, значение), например «0\r\nSECTION».
    final head = utf8.decode(
      bytes.sublist(0, bytes.length < 512 ? bytes.length : 512),
      allowMalformed: true,
    );
    if (head.contains('SECTION') ||
        head.contains('EOF') ||
        head.contains('HEADER')) {
      return CadFormat.dxf;
    }
    return CadFormat.unknown;
  }
}
