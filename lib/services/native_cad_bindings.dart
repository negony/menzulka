/// FFI-биндинги нативного слоя `menzulka_cad` (Rust + acadrust, MPL-2.0).
///
/// Библиотека собирается скриптом `tool/build_native.ps1`:
/// - Windows: `menzulka_cad.dll` рядом с `menzulka.exe`;
/// - Android: `libmenzulka_cad.so` в `jniLibs` (arm64-v8a, armeabi-v7a, x86_64).
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'cad_conversion_exception.dart';

typedef _DwgToDxfNative = Int32 Function(
  Pointer<Uint8> input,
  UintPtr inputLen,
  Pointer<Utf8> workDir,
  Uint32 flags,
  Pointer<Pointer<Uint8>> outPtr,
  Pointer<UintPtr> outLen,
  Pointer<Pointer<Uint8>> errPtr,
  Pointer<UintPtr> errLen,
);

typedef _DwgToDxfDart = int Function(
  Pointer<Uint8> input,
  int inputLen,
  Pointer<Utf8> workDir,
  int flags,
  Pointer<Pointer<Uint8>> outPtr,
  Pointer<UintPtr> outLen,
  Pointer<Pointer<Uint8>> errPtr,
  Pointer<UintPtr> errLen,
);

typedef _FreeNative = Void Function(Pointer<Uint8> ptr, UintPtr len);
typedef _FreeDart = void Function(Pointer<Uint8> ptr, int len);

typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

class NativeCadLibrary {
  NativeCadLibrary._();

  /// Опция нативного слоя: убрать геометрию блоков, на которые нет вставок.
  ///
  /// В чертежах Civil 3D часто остаются огромные блоки от удалённых
  /// 3D-поверхностей: файл 51 МБ даёт DXF 306 МБ, из которых 1 025 697 линий
  /// лежат в блоках без единого INSERT. Без фильтра такой DXF не помещается
  /// в память телефона.
  static const int flagFilterUnusedBlocks = 1;

  static const String _windowsLibrary = 'menzulka_cad.dll';
  static const String _androidLibrary = 'libmenzulka_cad.so';

  static DynamicLibrary? _library;
  static bool _openAttempted = false;
  static String? _loadError;

  /// Поддерживается ли платформа вообще.
  static bool get isSupportedPlatform =>
      Platform.isWindows || Platform.isAndroid;

  static String get libraryName =>
      Platform.isWindows ? _windowsLibrary : _androidLibrary;

  /// Причина, по которой библиотека не загрузилась (для сообщения пользователю).
  static String? get loadError => _loadError;

  /// Пути, по которым ищем библиотеку: рядом с exe, в папке сборки и
  /// (для тестов) относительный путь от корня проекта / переменная окружения.
  static List<String> get _candidatePaths {
    final override = Platform.environment['MENZULKA_CAD_LIB'];
    if (override != null && override.isNotEmpty) return [override, libraryName];
    if (Platform.isWindows) {
      return [libraryName, 'native/windows/$libraryName'];
    }
    return [libraryName];
  }

  static DynamicLibrary? _open() {
    if (_openAttempted) return _library;
    _openAttempted = true;
    if (!isSupportedPlatform) {
      _loadError = 'платформа не поддерживает нативный модуль DWG';
      return null;
    }
    final errors = <String>[];
    for (final path in _candidatePaths) {
      try {
        _library = DynamicLibrary.open(path);
        return _library;
      } on ArgumentError catch (e) {
        errors.add('${e.message} ($path)');
      } on Object catch (e) {
        errors.add('$e ($path)');
      }
    }
    _library = null;
    _loadError = 'не найдена библиотека $libraryName: ${errors.join('; ')}';
    debugPrint('NativeCad: $_loadError');
    return null;
  }

  /// Доступен ли нативный модуль конвертации.
  static bool get isAvailable => _open() != null;

  /// Версия нативного слоя и acadrust (или `null`, если библиотеки нет).
  static String? version() {
    final lib = _open();
    if (lib == null) return null;
    try {
      final fn =
          lib.lookupFunction<_VersionNative, _VersionDart>('menzulka_version');
      return fn().toDartString();
    } on Object catch (e) {
      debugPrint('NativeCad: не удалось прочитать версию: $e');
      return null;
    }
  }

  /// Конвертирует DWG-байты в DXF-байты. Бросает [CadConversionException].
  ///
  /// [flags] — опции нативного слоя; по умолчанию включена фильтрация
  /// неиспользуемых блоков (большой выигрыш по размеру и памяти).
  static Uint8List convert(
    Uint8List dwg,
    String workDir, {
    int flags = flagFilterUnusedBlocks,
  }) {
    final lib = _open();
    if (lib == null) {
      throw CadConversionException(
        CadConversionException.codeUnavailable,
        _loadError ?? 'нативный модуль DWG не найден',
      );
    }
    final fn = lib.lookupFunction<_DwgToDxfNative, _DwgToDxfDart>(
      'menzulka_dwg_to_dxf',
    );
    final free = lib.lookupFunction<_FreeNative, _FreeDart>('menzulka_free');

    final inputPtr = malloc.allocate<Uint8>(dwg.length);
    final workDirPtr = workDir.toNativeUtf8();
    final outPtr = malloc<Pointer<Uint8>>();
    final outLen = malloc<UintPtr>();
    final errPtr = malloc<Pointer<Uint8>>();
    final errLen = malloc<UintPtr>();
    outPtr.value = nullptr;
    errPtr.value = nullptr;
    outLen.value = 0;
    errLen.value = 0;

    try {
      inputPtr.asTypedList(dwg.length).setAll(0, dwg);
      final code = fn(
        inputPtr,
        dwg.length,
        workDirPtr,
        flags,
        outPtr,
        outLen,
        errPtr,
        errLen,
      );

      final int outSize = outLen.value;
      final int errSize = errLen.value;
      final output = outPtr.value;
      final error = errPtr.value;

      String? errorMessage;
      if (error != nullptr && errSize > 0) {
        errorMessage =
            utf8.decode(error.asTypedList(errSize), allowMalformed: true);
      }

      Uint8List? result;
      if (code == 0 && output != nullptr && outSize > 0) {
        result = Uint8List.fromList(output.asTypedList(outSize));
      }

      // Буферы принадлежат нативной библиотеке — освобождаем всегда.
      if (output != nullptr && outSize > 0) free(output, outSize);
      if (error != nullptr && errSize > 0) free(error, errSize);

      if (code != 0 || result == null) {
        throw CadConversionException(
          code == 0 ? 5 : code,
          errorMessage ?? 'не удалось сконвертировать DWG',
        );
      }
      return result;
    } finally {
      malloc.free(inputPtr);
      malloc.free(workDirPtr);
      malloc.free(outPtr);
      malloc.free(outLen);
      malloc.free(errPtr);
      malloc.free(errLen);
    }
  }
}
