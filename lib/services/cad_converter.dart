/// Конвертация DWG → DXF через нативный слой, в отдельном изоляте.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'cad_conversion_exception.dart';
import 'cad_export_version.dart';
import 'native_cad_bindings.dart';

/// Задача изолята для экспорта DWG.
class _DwgExportTask {
  const _DwgExportTask(this.dxf, this.workDir, this.reply, this.version);

  final Uint8List dxf;
  final String workDir;
  final SendPort reply;
  final DwgExportVersion version;
}

/// Точка входа изолята: DXF → DWG.
void _exportDwgInIsolate(_DwgExportTask task) {
  try {
    final dwg = NativeCadLibrary.dxfToDwg(
      task.dxf,
      task.workDir,
      flags: (task.version.flagBits << NativeCadLibrary.flagDwgVersionShift),
    );
    task.reply.send(<Object?>['ok', dwg]);
  } on CadConversionException catch (e) {
    task.reply.send(<Object?>['err', e.code, e.message]);
  } on Object catch (e) {
    task.reply.send(<Object?>['err', 6, e.toString()]);
  }
}

class _IsolateTask {
  const _IsolateTask(
    this.dwg,
    this.workDir,
    this.reply,
    this.filterUnusedBlocks,
  );

  final Uint8List dwg;
  final String workDir;
  final SendPort reply;
  final bool filterUnusedBlocks;
}

/// Точка входа изолята: конвертация и отправка результата.
void _convertInIsolate(_IsolateTask task) {
  try {
    final dxf = NativeCadLibrary.convert(
      task.dwg,
      task.workDir,
      flags:
          task.filterUnusedBlocks ? NativeCadLibrary.flagFilterUnusedBlocks : 0,
    );
    task.reply.send(<Object?>['ok', dxf]);
  } on CadConversionException catch (e) {
    task.reply.send(<Object?>['err', e.code, e.message]);
  } on Object catch (e) {
    task.reply.send(<Object?>['err', 5, e.toString()]);
  }
}

class CadConverter {
  const CadConverter._();

  /// Предельное время конвертации одного файла.
  static const Duration timeout = Duration(minutes: 5);

  /// Платформа поддерживает DWG (Android/Windows).
  static bool get isSupported => NativeCadLibrary.isSupportedPlatform;

  /// Нативный модуль реально загрузился.
  static bool get isAvailable => NativeCadLibrary.isAvailable;

  static String? get nativeVersion => NativeCadLibrary.version();

  /// Конвертирует DWG в DXF. Бросает [CadConversionException].
  ///
  /// [filterUnusedBlocks] — вырезать геометрию блоков без вставок: в чертежах
  /// Civil 3D это уменьшает DXF в десятки раз (306 МБ → 10–20 МБ).
  static Future<Uint8List> dwgToDxf(
    Uint8List dwg, {
    String? workDir,
    bool filterUnusedBlocks = true,
  }) async {
    if (!isAvailable) {
      throw const CadConversionException(
        CadConversionException.codeUnavailable,
        'нативный модуль DWG не найден',
      );
    }
    final cacheDir = workDir ?? (await getTemporaryDirectory()).path;
    final reply = ReceivePort();
    final completer = Completer<Uint8List>();
    Isolate? isolate;
    Timer? timer;

    void finishError(CadConversionException error) {
      if (completer.isCompleted) return;
      completer.completeError(error);
    }

    reply.listen((message) {
      if (completer.isCompleted) return;
      if (message is List && message.isNotEmpty) {
        if (message[0] == 'ok' && message.length >= 2) {
          completer.complete(Uint8List.fromList(message[1] as Uint8List));
          return;
        }
        if (message[0] == 'err' && message.length >= 3) {
          finishError(
            CadConversionException(message[1] as int, message[2] as String),
          );
          return;
        }
      }
      finishError(
        const CadConversionException(5, 'некорректный ответ нативного модуля'),
      );
    });

    try {
      isolate = await Isolate.spawn(
        _convertInIsolate,
        _IsolateTask(dwg, cacheDir, reply.sendPort, filterUnusedBlocks),
        debugName: 'dwg_to_dxf',
      );
    } on Object catch (e) {
      reply.close();
      throw CadConversionException(5, 'не удалось запустить изолят: $e');
    }

    timer = Timer(timeout, () {
      isolate?.kill(priority: Isolate.immediate);
      finishError(
        const CadConversionException(
          CadConversionException.codeTimeout,
          'превышено время конвертации DWG',
        ),
      );
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      reply.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  /// Экспорт: DXF-байты → DWG-байты. Бросает [CadConversionException].
  ///
  /// [version] — целевая версия DWG (2018 / 2013 / 2007).
  static Future<Uint8List> dxfToDwg(
    Uint8List dxf, {
    String? workDir,
    DwgExportVersion version = DwgExportVersion.r2018,
  }) async {
    if (!isAvailable) {
      throw const CadConversionException(
        CadConversionException.codeUnavailable,
        'нативный модуль DWG не найден',
      );
    }
    final cacheDir = workDir ?? (await getTemporaryDirectory()).path;
    final reply = ReceivePort();
    final completer = Completer<Uint8List>();
    Isolate? isolate;
    Timer? timer;

    void finishError(CadConversionException error) {
      if (completer.isCompleted) return;
      completer.completeError(error);
    }

    reply.listen((message) {
      if (completer.isCompleted) return;
      if (message is List && message.isNotEmpty) {
        if (message[0] == 'ok' && message.length >= 2) {
          completer.complete(Uint8List.fromList(message[1] as Uint8List));
          return;
        }
        if (message[0] == 'err' && message.length >= 3) {
          finishError(
            CadConversionException(message[1] as int, message[2] as String),
          );
          return;
        }
      }
      finishError(
        const CadConversionException(
            CadConversionException.codeWriteFailed, 'некорректный ответ'),
      );
    });

    try {
      isolate = await Isolate.spawn(
        _exportDwgInIsolate,
        _DwgExportTask(dxf, cacheDir, reply.sendPort, version),
        debugName: 'dxf_to_dwg',
      );
    } on Object catch (e) {
      reply.close();
      throw CadConversionException(CadConversionException.codeWriteFailed,
          'не удалось запустить изолят: $e');
    }

    timer = Timer(timeout, () {
      isolate?.kill(priority: Isolate.immediate);
      finishError(
        const CadConversionException(
          CadConversionException.codeTimeout,
          'превышено время записи DWG',
        ),
      );
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      reply.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  /// Для тестов: DXF → DWG синхронно.
  @visibleForTesting
  static Uint8List dxfToDwgSync(
    Uint8List dxf, {
    required String workDir,
    DwgExportVersion version = DwgExportVersion.r2018,
  }) {
    return NativeCadLibrary.dxfToDwg(
      dxf,
      workDir,
      flags: version.flagBits << NativeCadLibrary.flagDwgVersionShift,
    );
  }

  /// Для тестов: конвертировать синхронно (в текущем изоляте, без таймаута).
  @visibleForTesting
  static Uint8List dwgToDxfSync(
    Uint8List dwg, {
    required String workDir,
    bool filterUnusedBlocks = true,
  }) {
    return NativeCadLibrary.convert(
      dwg,
      workDir,
      flags: filterUnusedBlocks ? NativeCadLibrary.flagFilterUnusedBlocks : 0,
    );
  }
}
